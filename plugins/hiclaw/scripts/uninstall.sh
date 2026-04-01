#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# HiClaw 卸载脚本


echo "正在卸载 HiClaw..."

# 停止并移除容器
docker stop hiclaw-manager 2>/dev/null || true
docker rm hiclaw-manager 2>/dev/null || true

# 停止并移除所有 worker 容器
for w in $(docker ps -a --format '{{.Names}}' | grep "^hiclaw-worker-" || true); do
  docker stop "${w}" 2>/dev/null || true
  docker rm "${w}" 2>/dev/null || true
done

# 移除 Docker 卷
docker volume rm hiclaw-data 2>/dev/null || true

# 清理安装脚本
rm -f /tmp/hiclaw-install.sh 2>/dev/null || true

echo "HiClaw 卸载完成"