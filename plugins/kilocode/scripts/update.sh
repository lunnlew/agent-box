#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

PKG_NAME="@kilocode/cli"
PKG_PATH="$(npm root -g 2>/dev/null)/@kilocode/cli"

log_info "Updating Kilocode CLI..."

# 备份用户配置
if [ -d ~/.config/kilo ]; then
  cp -r ~/.config/kilo ~/.config/kilo.bak.$(date +%Y%m%d%H%M%S) 2>/dev/null || true
fi

# 更新
npm update -g "$PKG_NAME" || {
  log_warning "Update failed, reinstalling..."
  npm install -g "$PKG_NAME"@latest
}

# 验证
if [ ! -f "$PKG_PATH/package.json" ]; then
  log_error "Update verification failed"
  if [ -d ~/.config/kilo.bak.* ]; then
    mv ~/.config/kilo.bak.* ~/.config/kilo 2>/dev/null || true
  fi
  exit 1
fi

kilocode --version
log_success "Kilocode CLI updated successfully"

# 清理备份
rm -rf ~/.config/kilo.bak.* 2>/dev/null || true