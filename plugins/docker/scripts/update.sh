#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

DOCKER_VERSION="${DOCKER_VERSION:-28.0.1}"

log_info "Updating Docker CLI..."

ARCH=$(uname -m)
case $ARCH in
  x86_64) ARCH="x86_64" ;;
  aarch64) ARCH="aarch64" ;;
  *) log_error "Unsupported architecture: $ARCH"; exit 1 ;;
esac

URL="https://download.docker.com/linux/static/stable/${ARCH}/docker-${DOCKER_VERSION}.tgz"

log_info "Downloading Docker ${DOCKER_VERSION}..."

# 下载（支持代理）
if [ -n "$INSTALL_PROXY" ]; then
  curl -fsSL --proxy "$INSTALL_PROXY" -o /tmp/docker.tgz "$URL"
elif [ -n "$HTTPS_PROXY" ]; then
  curl -fsSL --proxy "$HTTPS_PROXY" -o /tmp/docker.tgz "$URL"
else
  curl -fsSL -o /tmp/docker.tgz "$URL"
fi

# 解压安装（覆盖旧版本）
tar -xzf /tmp/docker.tgz -C /tmp
mv /tmp/docker/docker $HOME/tools/bin/

# 清理临时文件
rm -rf /tmp/docker /tmp/docker.tgz

# 验证
docker --version
log_success "Docker CLI updated successfully"