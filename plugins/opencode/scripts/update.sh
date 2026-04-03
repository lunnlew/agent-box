#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

PKG_NAME="opencode-ai"
PKG_PATH="$(npm root -g 2>/dev/null)/opencode-ai"

log_info "Updating OpenCode AI..."

# 备份用户配置
if [ -d ~/.opencode ]; then
  cp -r ~/.opencode ~/.opencode.bak.$(date +%Y%m%d%H%M%S) 2>/dev/null || true
fi

# 更新
npm update -g "$PKG_NAME" || {
  log_warning "Update failed, reinstalling..."
  npm install -g "$PKG_NAME"@latest
}

# 验证
if [ ! -f "$PKG_PATH/package.json" ]; then
  log_error "Update verification failed"
  if [ -d ~/.opencode.bak.* ]; then
    mv ~/.opencode.bak.* ~/.opencode 2>/dev/null || true
  fi
  exit 1
fi

opencode --version
log_success "OpenCode AI updated successfully"

# 清理备份
rm -rf ~/.opencode.bak.* 2>/dev/null || true