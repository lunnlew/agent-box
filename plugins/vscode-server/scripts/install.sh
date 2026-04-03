#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

log_info "Installing VS Code Server (code-server)..."

# 完全清理旧版本和缓存
log_info "Cleaning up old installation..."
find ~/.code-server/lib -maxdepth 1 -type d -name "code-server-*" -exec rm -rf {} \; 2>/dev/null || true
rm -rf ~/.cache/code-server/* 2>/dev/null || true
rm -f ~/.code-server/bin/code-server 2>/dev/null || true

# 创建必要目录
mkdir -p ~/.code-server/lib ~/.code-server/bin ~/.cache/code-server

# 执行安装脚本（支持代理）
log_info "Downloading and running install script..."

TEMP_SCRIPT=$(mktemp)

if [ -n "$INSTALL_PROXY" ]; then
  curl -fsSLk --connect-timeout 30 --max-time 600 --retry 3 --proxy "$INSTALL_PROXY" https://code-server.dev/install.sh -o "$TEMP_SCRIPT"
elif [ -n "$HTTPS_PROXY" ]; then
  curl -fsSLk --connect-timeout 30 --max-time 600 --retry 3 --proxy "$HTTPS_PROXY" https://code-server.dev/install.sh -o "$TEMP_SCRIPT"
else
  curl -fsSLk --connect-timeout 30 --max-time 600 --retry 3 https://code-server.dev/install.sh -o "$TEMP_SCRIPT"
fi

if [ ! -s "$TEMP_SCRIPT" ]; then
  log_error "Failed to download install script"
  rm -f "$TEMP_SCRIPT"
  exit 1
fi

log_info "Install script downloaded to $TEMP_SCRIPT"
chmod +x "$TEMP_SCRIPT"

# 执行安装脚本
bash "$TEMP_SCRIPT" --method standalone
install_result=$?

rm -f "$TEMP_SCRIPT"

if [ $install_result -ne 0 ]; then
  log_error "Install script exited with code $install_result"
  exit 1
fi

# 验证安装
log_info "Verifying installation..."

sleep 2

# 检查 lib 目录下的安装
latest_version=$(ls -d ~/.code-server/lib/code-server-* 2>/dev/null | head -1)
if [ -n "$latest_version" ] && [ -f "$latest_version/bin/code-server" ]; then
    ln -sf "$latest_version/bin/code-server" ~/.code-server/bin/code-server
    log_info "Created symlink: ~/.code-server/bin/code-server"
fi

if [ ! -f ~/.code-server/bin/code-server ] && ! command -v code-server &>/dev/null; then
  log_error "Installation failed: code-server binary not found"
  exit 1
fi

~/.code-server/bin/code-server --version
log_success "VS Code Server installed successfully"