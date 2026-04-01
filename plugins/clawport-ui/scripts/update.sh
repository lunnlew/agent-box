#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# ClawPort UI 更新脚本


NPM_ROOT=$(npm root -g 2>/dev/null)
CLAWPORT_PATH="$NPM_ROOT/clawport-ui"

log_info "Updating ClawPort UI..."

# 停止当前服务
pkill -f "clawport" 2>/dev/null || true
pkill -f "next.*server" 2>/dev/null || true

# 更新（覆盖安装）
npm install -g clawport-ui@latest || {
  log_warning "Update failed, reinstalling..."
  npm install -g clawport-ui@latest
}

# 验证更新
if [ ! -f "$CLAWPORT_PATH/package.json" ]; then
  log_error "Update verification failed"
  exit 1
fi

clawport --version
log_success "ClawPort UI updated successfully"