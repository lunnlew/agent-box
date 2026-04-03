#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

PKG_NAME="@qwen-code/qwen-code"
NPM_ROOT=$(npm root -g 2>/dev/null)
PKG_PATH="$NPM_ROOT/@qwen-code/qwen-code"
NPM_PREFIX=$(npm prefix -g 2>/dev/null)
PKG_BIN="$NPM_PREFIX/bin/qwen"

log_info "NPM root: $NPM_ROOT"
log_info "NPM prefix: $NPM_PREFIX"
log_info "Installing Qwen Code..."

# 清理旧版本
log_info "Cleaning up existing installation..."
npm uninstall -g "$PKG_NAME" 2>/dev/null || true
[ -d "$PKG_PATH" ] && rm -rf "$PKG_PATH" 2>/dev/null || true
[ -L "$PKG_BIN" ] && rm -f "$PKG_BIN" 2>/dev/null || true
[ -f "$PKG_BIN" ] && rm -f "$PKG_BIN" 2>/dev/null || true

# 清理临时目录
for tmp_dir in "$NPM_ROOT"/.qwen-code-*; do
  [ -d "$tmp_dir" ] && rm -rf "$tmp_dir" 2>/dev/null || true
done

# 安装（使用智能安装）
log_info "Installing package..."
if type net_npm_install &>/dev/null; then
  net_npm_install "$PKG_NAME"
else
  if ! npm install -g "$PKG_NAME"; then
    log_warning "First attempt failed, retrying..."
    sleep 2
    npm install -g "$PKG_NAME"
  fi
fi

# 创建符号链接（如果需要）
if [ ! -L "$PKG_BIN" ] && [ ! -f "$PKG_BIN" ]; then
  log_info "Creating symlink manually..."
  mkdir -p "$(dirname "$PKG_BIN")"
  ln -sf "$PKG_PATH/cli.js" "$PKG_BIN"
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
for tmp_dir in "$NPM_ROOT"/.qwen-code-*; do
  [ -d "$tmp_dir" ] && rm -rf "$tmp_dir" 2>/dev/null || true
done

qwen --version
log_success "Qwen Code installed successfully"