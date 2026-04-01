#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

log_info "Updating OpenSpace..."

# 检查安装
if [ ! -d ~/openspace-src ]; then
  log_error "OpenSpace not installed. Run 'agentbox install openspace' first."
  exit 1
fi

cd ~/openspace-src

# 拉取最新代码
log_info "Pulling latest code..."
git pull || log_warning "Git pull failed, continuing..."

# 激活虚拟环境并重新安装
log_info "Updating Python dependencies..."
source .venv/bin/activate
pip install -e . 2>&1 | tail -10

# 更新前端依赖（如果存在）
if [ -d ~/openspace-src/frontend ]; then
  log_info "Updating frontend dependencies..."
  cd ~/openspace-src/frontend
  npm install 2>&1 | tail -5 || log_warning "Frontend update failed"
  cd ~/openspace-src
fi

log_success "OpenSpace updated successfully"
log_info "Restart Dashboard if running: agentbox restart openspace"