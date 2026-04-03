#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}


# DeerFlow 停止脚本

cd ~/deer-flow 2>/dev/null || true

# 修复权限
chown -R agent:agent ~/.docker 2>/dev/null || true
chmod -R 755 ~/.docker 2>/dev/null || true
mkdir -p ~/.docker/buildx/activity
chown -R agent:agent ~/.docker/buildx 2>/dev/null || true
chmod -R 755 ~/.docker/buildx 2>/dev/null || true

# 设置 DEER_FLOW_ROOT
export DEER_FLOW_ROOT="$(bash ~/plugins-config/deer-flow/scripts/setup-docker-root.sh ~/deer-flow)"

# 停止服务
make docker-stop 2>/dev/null || true
docker stop deer-flow 2>/dev/null || true

echo "DeerFlow stopped"