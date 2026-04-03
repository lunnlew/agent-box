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
NPM_ROOT=$(npm root -g 2>/dev/null)
PKG_PATH="$NPM_ROOT/opencode-ai"
NPM_PREFIX=$(npm prefix -g 2>/dev/null)
PKG_BIN="$NPM_PREFIX/bin/opencode"

log_info "NPM root: $NPM_ROOT"
log_info "NPM prefix: $NPM_PREFIX"
log_info "Installing OpenCode AI..."

# 清理旧版本
log_info "Cleaning up existing installation..."
npm uninstall -g "$PKG_NAME" 2>/dev/null || true
[ -d "$PKG_PATH" ] && rm -rf "$PKG_PATH" 2>/dev/null || true
[ -L "$PKG_BIN" ] && rm -f "$PKG_BIN" 2>/dev/null || true
[ -f "$PKG_BIN" ] && rm -f "$PKG_BIN" 2>/dev/null || true

# 清理临时目录
for tmp_dir in "$NPM_ROOT"/.opencode-*; do
  [ -d "$tmp_dir" ] && rm -rf "$tmp_dir" 2>/dev/null || true
done

# 安装
log_info "Installing package..."
if ! npm install -g "$PKG_NAME"; then
  log_warning "First attempt failed, retrying..."
  sleep 2
  npm install -g "$PKG_NAME"
fi

# 验证安装
log_info "Verifying installation..."
if [ ! -f "$PKG_PATH/package.json" ]; then
  log_error "Installation incomplete: package.json missing"
  exit 1
fi

if [ ! -L "$PKG_BIN" ] && [ ! -f "$PKG_BIN" ]; then
  log_error "Installation incomplete: binary not found at $PKG_BIN"
  exit 1
fi

# 清理临时目录
for tmp_dir in "$NPM_ROOT"/.opencode-*; do
  [ -d "$tmp_dir" ] && rm -rf "$tmp_dir" 2>/dev/null || true
done

opencode --version
log_success "OpenCode AI installed successfully"