#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

log_info "Stopping OpenSpace Dashboard..."

# 停止 Dashboard Backend
if pgrep -f "openspace-dashboard" >/dev/null 2>&1; then
  log_info "Stopping Dashboard backend..."
  pkill -f "openspace-dashboard" 2>/dev/null || true
fi

# 停止 Dashboard Frontend
if pgrep -f "vite.*openspace" >/dev/null 2>&1; then
  log_info "Stopping Dashboard frontend..."
  pkill -f "vite.*openspace" 2>/dev/null || true
fi

# 也尝试通过端口匹配
OPENSPACE_PORT="${OPENSPACE_PORT:-7788}"
OPENSPACE_FRONTEND_PORT="${OPENSPACE_FRONTEND_PORT:-5174}"

pkill -f "openspace-dashboard --port $OPENSPACE_PORT" 2>/dev/null || true
pkill -f "npm run dev.*$OPENSPACE_FRONTEND_PORT" 2>/dev/null || true

sleep 2

# 检查是否已停止
if pgrep -f "openspace-dashboard" >/dev/null 2>&1; then
  log_warning "Dashboard backend still running, force kill..."
  pkill -9 -f "openspace-dashboard" 2>/dev/null || true
fi

if pgrep -f "vite.*openspace" >/dev/null 2>&1; then
  log_warning "Dashboard frontend still running, force kill..."
  pkill -9 -f "vite.*openspace" 2>/dev/null || true
fi

log_success "OpenSpace Dashboard stopped"