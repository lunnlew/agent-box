#!/bin/bash
# OpenClaw 安装脚本
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
OPENCLAW_PATH="$NPM_ROOT/openclaw"
OPENCLAW_BIN="$NPM_BIN/openclaw"

log_info "NPM root: $NPM_ROOT"
log_info "NPM prefix: $NPM_PREFIX"
log_info "NPM bin: $NPM_BIN"

# 清理残留的临时目录（npm 安装中断会留下 .openclaw-* 目录）
log_info "Cleaning up temp directories..."
for tmp_dir in "$NPM_ROOT"/.openclaw-*; do
  if [ -d "$tmp_dir" ]; then
    rm -rf "$tmp_dir" 2>/dev/null || true
    log_info "  Removed temp dir: $tmp_dir"
  fi
done

# 卸载旧版本
log_info "Uninstalling existing openclaw..."
npm uninstall -g openclaw 2>/dev/null || true

# 清理残留目录
if [ -d "$OPENCLAW_PATH" ]; then
  rm -rf "$OPENCLAW_PATH" 2>/dev/null || true
  log_info "  Removed existing: $OPENCLAW_PATH"
fi
if [ -L "$OPENCLAW_BIN" ]; then
  rm -f "$OPENCLAW_BIN" 2>/dev/null || true
  log_info "  Removed symlink: $OPENCLAW_BIN"
fi

# 全局安装（使用智能安装函数）
log_info "Installing openclaw@latest..."
if type net_npm_install &>/dev/null; then
  net_npm_install "openclaw@latest"
else
  # 回退到原有逻辑
  if ! npm install -g openclaw@latest; then
    log_warning "npm install failed, retrying..."
    sleep 2
    npm install -g openclaw@latest
  fi
fi

# 验证安装完整性
log_info "Verifying installation..."

# 检查 package.json 是否存在
if [ ! -f "$OPENCLAW_PATH/package.json" ]; then
  log_error "package.json not found, installation incomplete!"
  exit 1
fi

# 检查主执行文件是否存在
if [ ! -f "$OPENCLAW_PATH/openclaw.mjs" ]; then
  log_error "openclaw.mjs not found, installation incomplete!"
  exit 1
fi

# 检查符号链接是否存在
if [ ! -L "$OPENCLAW_BIN" ] && [ ! -f "$OPENCLAW_BIN" ]; then
  log_warning "Binary symlink not found at $OPENCLAW_BIN"
  # 尝试备用路径
  if [ -L "$HOME/tools/bin/openclaw" ] || [ -f "$HOME/tools/bin/openclaw" ]; then
    log_info "Binary found at $HOME/tools/bin/openclaw, creating symlink..."
    mkdir -p "$(dirname "$OPENCLAW_BIN")"
    ln -sf "$HOME/tools/bin/openclaw" "$OPENCLAW_BIN" 2>/dev/null || true
  else
    log_error "Binary also not found at $HOME/tools/bin/openclaw"
    log_info "Available binaries in $HOME/tools/bin:"
    ls -la "$HOME/tools/bin/" 2>/dev/null | grep -i openclaw || echo "(none)"
    exit 1
  fi
fi

# 清理可能的临时目录（如果安装后还有残留）
for tmp_dir in "$NPM_ROOT"/.openclaw-*; do
  [ -d "$tmp_dir" ] && rm -rf "$tmp_dir" 2>/dev/null || true
done

log_success "openclaw installed successfully"