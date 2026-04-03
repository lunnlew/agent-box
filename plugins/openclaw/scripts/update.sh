#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# OpenClaw 更新脚本


NPM_ROOT=$(npm root -g 2>/dev/null)
NPM_PREFIX=$(npm prefix -g 2>/dev/null)
OPENCLAW_PATH="$NPM_ROOT/openclaw"

log_info "Updating OpenClaw..."

# 更新
npm update -g openclaw@latest || {
  log_warning "Update failed, reinstalling..."
  npm install -g openclaw@latest
}

# 验证
if [ ! -f "$OPENCLAW_PATH/package.json" ]; then
  log_error "Update verification failed"
  exit 1
fi

openclaw --version
log_success "OpenClaw updated successfully"