#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

OPENSPACE_PORT="${OPENSPACE_PORT:-7788}"
OPENSPACE_FRONTEND_PORT="${OPENSPACE_FRONTEND_PORT:-5174}"
VENV_DIR="$HOME/openspace-src"
SRC_DIR="$HOME/openspace-src"

log_info "Starting OpenSpace Dashboard..."

# 检查安装
if [ ! -d "$VENV_DIR/.venv" ]; then
  log_error "OpenSpace not installed. Run 'agentbox install openspace' first."
  exit 1
fi

# 创建必要的目录
mkdir -p ~/logs
mkdir -p ~/.openspace/logs

# 修复源码目录权限（如果需要）
if [ -d "$SRC_DIR" ] && [ ! -w "$SRC_DIR" ]; then
  log_info "Fixing source directory permissions..."
  chown -R agent:agent "$SRC_DIR" 2>/dev/null || chmod -R u+rw "$SRC_DIR" 2>/dev/null || true
fi

# 确保 logs 目录存在
mkdir -p "$SRC_DIR/logs" 2>/dev/null || true

# 清理残留进程（排除当前脚本进程）
cleanup_stale_processes() {
  local port=$1

  local pids=$(lsof -ti:$port 2>/dev/null || true)

  if [ -n "$pids" ]; then
    for pid in $pids; do
      local cmdline=$(cat /proc/$pid/cmdline 2>/dev/null | tr '\0' ' ' || echo "")
      if [[ "$cmdline" == *"openspace-dashboard"* ]] || [[ "$cmdline" == *"dashboard_server"* ]]; then
        log_info "  Cleaning stale process: PID $pid"
        kill -9 "$pid" 2>/dev/null || true
      fi
    done
    sleep 1
  fi
}

# 清理残留进程
cleanup_stale_processes "$OPENSPACE_PORT"

# 设置工作目录
cd ~

# 设置环境变量
export OPENSPACE_WORKSPACE="${OPENSPACE_WORKSPACE:-$HOME/.openspace}"
export OPENSPACE_LOG_DIR="${OPENSPACE_LOG_DIR:-$HOME/.openspace/logs}"

log_info "Starting Dashboard backend on port $OPENSPACE_PORT..."

# 启动后端（后台运行，由 Supervisor 管理）
if [ -f "$VENV_DIR/.venv/bin/openspace-dashboard" ]; then
  "$VENV_DIR/.venv/bin/openspace-dashboard" --port "$OPENSPACE_PORT" &
  BACKEND_PID=$!
elif [ -f "$VENV_DIR/.venv/bin/python" ]; then
  "$VENV_DIR/.venv/bin/python" -m openspace.dashboard_server --port "$OPENSPACE_PORT" &
  BACKEND_PID=$!
else
  log_error "No openspace-dashboard command found"
  exit 1
fi

log_info "Backend started (PID: $BACKEND_PID)"

# 等待后端启动
sleep 3

# 启动前端开发服务器（如果 frontend 目录存在）
FRONTEND_DIR="$SRC_DIR/frontend"
if [ -d "$FRONTEND_DIR" ] && [ -f "$FRONTEND_DIR/package.json" ]; then
  log_info "Starting Dashboard frontend on port $OPENSPACE_FRONTEND_PORT..."

  # 清理旧的前端进程
  pkill -f "vite.*$OPENSPACE_FRONTEND_PORT" 2>/dev/null || true
  sleep 1

  cd "$FRONTEND_DIR"

  # 设置后端 API 地址
  export VITE_API_URL="http://localhost:$OPENSPACE_PORT"

  # 检查是否需要安装依赖
  if [ ! -d "node_modules" ]; then
    log_info "Installing frontend dependencies..."
    npm install 2>&1 | tail -5
  fi

  # 启动前端开发服务器
  nohup npm run dev -- --port "$OPENSPACE_FRONTEND_PORT" --host > ~/logs/openspace-frontend.log 2>&1 &
  FRONTEND_PID=$!
  log_info "Frontend started (PID: $FRONTEND_PID)"

  cd ~
else
  log_warning "Frontend directory not found, skipping frontend startup"
fi

log_success "OpenSpace Dashboard started"
log_info ""
log_info "Access URLs:"
log_info "  Backend API:  http://localhost:$OPENSPACE_PORT"
log_info "  Frontend UI:  http://localhost:$OPENSPACE_FRONTEND_PORT"
log_info ""
log_info "Logs:"
log_info "  Backend:  ~/logs/openspace.log"
log_info "  Frontend: ~/logs/openspace-frontend.log"

# 保持脚本运行（等待子进程）
wait