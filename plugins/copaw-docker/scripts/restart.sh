#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# CoPaw Docker 重启脚本

log_info "Restarting CoPaw Docker..."

docker restart copaw-docker || true

sleep 3

if docker ps --filter name=copaw-docker --filter status=running -q | grep -q .; then
  log_success "CoPaw Docker restarted successfully"
else
  log_error "Failed to restart CoPaw Docker. Check logs: docker logs copaw-docker"
  exit 1
fi