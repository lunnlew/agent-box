#!/bin/bash
# ClawPort UI 安装脚本
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# 获取 npm 全局安装路径
NPM_ROOT=$(npm root -g 2>/dev/null)
# npm 10.x 不支持 bin -g，使用 prefix + /bin 替代
NPM_PREFIX=$(npm prefix -g 2>/dev/null)
NPM_BIN="$NPM_PREFIX/bin"
CLAWPORT_PATH="$NPM_ROOT/clawport-ui"
CLAWPORT_BIN="$NPM_BIN/clawport"

log_info "NPM root: $NPM_ROOT"
log_info "NPM prefix: $NPM_PREFIX"
log_info "NPM bin: $NPM_BIN"

# 清理残留的临时目录
log_info "Cleaning up temp directories..."
for tmp_dir in "$NPM_ROOT"/.clawport-ui-*; do
  if [ -d "$tmp_dir" ]; then
    rm -rf "$tmp_dir" 2>/dev/null || true
    log_info "  Removed temp dir: $tmp_dir"
  fi
done

# 卸载旧版本
log_info "Uninstalling existing clawport-ui..."
npm uninstall -g clawport-ui 2>/dev/null || true

# 清理残留目录
if [ -d "$CLAWPORT_PATH" ]; then
  rm -rf "$CLAWPORT_PATH" 2>/dev/null || true
  log_info "  Removed existing: $CLAWPORT_PATH"
fi
if [ -L "$CLAWPORT_BIN" ]; then
  rm -f "$CLAWPORT_BIN" 2>/dev/null || true
  log_info "  Removed symlink: $CLAWPORT_BIN"
fi

# 全局安装
log_info "Installing clawport-ui@latest..."
if ! npm install -g clawport-ui@latest; then
  log_warning "npm install failed, retrying..."
  sleep 2
  npm install -g clawport-ui@latest
fi

# 验证安装完整性
log_info "Verifying installation..."

# 检查 package.json 是否存在
if [ ! -f "$CLAWPORT_PATH/package.json" ]; then
  log_error "package.json not found, installation incomplete!"
  exit 1
fi

# 检查 CLI 命令是否可用
if ! command -v clawport &>/dev/null; then
  log_error "clawport command not found, installation incomplete!"
  log_info "Available binaries in $HOME/tools/bin:"
  ls -la "$HOME/tools/bin/" 2>/dev/null | grep -i clawport || echo "(none)"
  exit 1
fi

# 清理可能的临时目录
for tmp_dir in "$NPM_ROOT"/.clawport-ui-*; do
  [ -d "$tmp_dir" ] && rm -rf "$tmp_dir" 2>/dev/null || true
done

log_success "ClawPort UI installed successfully"