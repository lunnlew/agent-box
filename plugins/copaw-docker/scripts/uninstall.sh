#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# CoPaw Docker 卸载脚本

log_info "Uninstalling CoPaw Docker..."

# 停止并删除容器
log_info "Stopping and removing container..."
docker stop copaw-docker 2>/dev/null || true
docker rm copaw-docker 2>/dev/null || true

# 删除镜像
log_info "Removing Docker image..."
COPAW_DOCKER_IMAGE=${COPAW_DOCKER_IMAGE:-agentscope/copaw:latest}
docker rmi "$COPAW_DOCKER_IMAGE" 2>/dev/null || true

# 询问是否删除 volumes（保留数据）
log_warning "Docker volumes (copaw-data, copaw-secrets) are preserved."
log_info "To remove volumes manually: docker volume rm copaw-data copaw-secrets"

log_success "CoPaw Docker uninstalled successfully"