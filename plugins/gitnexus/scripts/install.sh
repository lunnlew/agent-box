#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  # 如果不在容器内，定义简化版日志函数
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# 获取插件定义目录（支持容器内和本地两种环境）
if [ -n "$PLUGINS_DEF_DIR" ]; then
  SCRIPT_DIR="$PLUGINS_DEF_DIR/gitnexus/scripts"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

log_info "Installing GitNexus..."

# 构建 GitNexus 专用镜像（基于 Ubuntu 24.04，GLIBC 2.39）
# 构建上下文为插件根目录，以包含 patch 文件
log_info "Building GitNexus Docker image..."
docker build -t gitnexus-runner:latest -f "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR/.."

# 创建数据目录
mkdir -p ~/.gitnexus

# 克隆源码
log_info "Cloning GitNexus repository..."
if [ -d ~/gitnexus-src ]; then
  cd ~/gitnexus-src
  git pull || true
else
  git clone https://github.com/abhigyanpatwari/GitNexus.git ~/gitnexus-src
fi

log_success "GitNexus installed successfully"
log_info "Run 'agentbox start gitnexus' to start services"