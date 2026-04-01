#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

TTYD_VERSION="${TTYD_VERSION:-1.7.7}"

log_info "Installing Web Terminal (ttyd)..."

ARCH=$(uname -m)
case $ARCH in
  x86_64) ARCH="x86_64" ;;
  aarch64) ARCH="aarch64" ;;
  *) log_error "Unsupported architecture: $ARCH"; exit 1 ;;
esac

URL="https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${ARCH}"

log_info "Downloading ttyd ${TTYD_VERSION} for ${ARCH}..."

# 下载（支持代理）
if [ -n "$INSTALL_PROXY" ]; then
  curl -fsSL --proxy "$INSTALL_PROXY" -o /tmp/ttyd "$URL"
elif [ -n "$HTTPS_PROXY" ]; then
  curl -fsSL --proxy "$HTTPS_PROXY" -o /tmp/ttyd "$URL"
else
  curl -fsSL -o /tmp/ttyd "$URL"
fi

# 安装
chmod +x /tmp/ttyd
mv /tmp/ttyd $HOME/tools/bin/ttyd

# 验证安装
if ! command -v ttyd &>/dev/null; then
  log_error "Installation failed: ttyd command not found"
  exit 1
fi

ttyd --version
log_success "Web Terminal installed successfully"