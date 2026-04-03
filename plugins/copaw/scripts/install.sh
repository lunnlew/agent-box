#!/bin/bash
# CoPaw 安装脚本
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

log_info "Installing CoPaw..."

# 确保缓存目录存在且有正确权限
log_info "Setting up uv cache directory..."
mkdir -p ~/.cache/uv
chmod -R 755 ~/.cache/uv 2>/dev/null || true
chown -R "$(id -u):$(id -g)" ~/.cache/uv 2>/dev/null || true

# 完全清理并重新创建 uv 缓存目录，确保权限正确
log_info "Cleaning uv cache..."
rm -rf ~/.cache/uv/* 2>/dev/null || true

# 设置 UV 环境变量，禁用缓存
export UV_CACHE_DIR=~/.cache/uv
export UV_NO_CACHE=1

# 完全清理旧版本 - 包括所有目录但保留用户数据
log_info "Cleaning up old installation..."
rm -rf ~/.copaw/bin 2>/dev/null || true
rm -rf ~/.copaw/venv 2>/dev/null || true
rm -rf ~/.copaw/cache 2>/dev/null || true
rm -rf ~/.copaw/state 2>/dev/null || true

# 执行安装脚本（支持代理）
log_info "Downloading and running install script..."

# 先下载到临时文件，再执行
TEMP_SCRIPT=$(mktemp)

if [ -n "$INSTALL_PROXY" ]; then
  curl -fsSL --connect-timeout 30 --max-time 600 --retry 3 --proxy "$INSTALL_PROXY" https://copaw.agentscope.io/install.sh -o "$TEMP_SCRIPT"
elif [ -n "$HTTPS_PROXY" ]; then
  curl -fsSL --connect-timeout 30 --max-time 600 --retry 3 --proxy "$HTTPS_PROXY" https://copaw.agentscope.io/install.sh -o "$TEMP_SCRIPT"
else
  curl -fsSL --connect-timeout 30 --max-time 600 --retry 3 https://copaw.agentscope.io/install.sh -o "$TEMP_SCRIPT"
fi

if [ ! -s "$TEMP_SCRIPT" ]; then
  log_error "Failed to download install script"
  rm -f "$TEMP_SCRIPT"
  exit 1
fi

log_info "Install script downloaded to $TEMP_SCRIPT"
chmod +x "$TEMP_SCRIPT"

# 执行安装脚本（非交互式）
bash "$TEMP_SCRIPT"
install_result=$?

rm -f "$TEMP_SCRIPT"

if [ $install_result -ne 0 ]; then
  log_error "Install script exited with code $install_result"
  exit 1
fi

# 验证安装
log_info "Verifying installation..."

# 等待一下确保文件已创建
sleep 2

# 检查并创建符号链接
if [ -d ~/.copaw/venv/bin ] && [ -f ~/.copaw/venv/bin/copaw ]; then
  mkdir -p ~/.local/bin
  ln -sf ~/.copaw/venv/bin/copaw ~/.local/bin/copaw
  log_info "Created symlink: ~/.local/bin/copaw"
fi

# 刷新 PATH
export PATH="$HOME/.local/bin:$PATH"

if ! command -v copaw &>/dev/null; then
  log_error "Installation failed: copaw command not found"
  log_error "Available in ~/.copaw/venv/bin:"
  ls -la ~/.copaw/venv/bin/ 2>/dev/null || echo "(directory not found)"
  exit 1
fi

copaw -h >/dev/null 2>&1 || {
  log_error "Installation verification failed: copaw -h failed"
  exit 1
}

log_success "CoPaw installed successfully"