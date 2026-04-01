#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

PKG_NAME="@openai/codex"
PKG_PATH="$(npm root -g 2>/dev/null)/@openai/codex"

log_info "Updating OpenAI Codex..."

# 备份用户配置
if [ -d ~/.codex ]; then
  cp -r ~/.codex ~/.codex.bak.$(date +%Y%m%d%H%M%S) 2>/dev/null || true
fi

# 更新
npm update -g "$PKG_NAME" || {
  log_warning "Update failed, reinstalling..."
  npm install -g "$PKG_NAME"@latest
}

# 验证
if [ ! -f "$PKG_PATH/package.json" ]; then
  log_error "Update verification failed"
  if [ -d ~/.codex.bak.* ]; then
    mv ~/.codex.bak.* ~/.codex 2>/dev/null || true
  fi
  exit 1
fi

codex --version
log_success "OpenAI Codex updated successfully"

# 清理备份
rm -rf ~/.codex.bak.* 2>/dev/null || true