#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}


echo ""
echo "============================================"
echo "  Docker CLI 安装完成!"
echo "============================================"
echo ""
echo "二进制文件：~/tools/bin/docker"
echo ""
echo "连接到 Docker Daemon:"
echo "  export DOCKER_HOST=tcp://host.docker.internal:2375"
echo ""
echo "使用示例:"
echo "  docker ps"
echo "  docker images"
echo "============================================"
echo ""