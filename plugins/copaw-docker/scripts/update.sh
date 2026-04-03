#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# CoPaw Docker 更新脚本

log_info "Updating CoPaw Docker..."

COPAW_DOCKER_IMAGE=${COPAW_DOCKER_IMAGE:-agentscope/copaw:latest}

# 停止容器
log_info "Stopping container..."
docker stop copaw-docker 2>/dev/null || true

# 删除旧容器
log_info "Removing old container..."
docker rm copaw-docker 2>/dev/null || true

# 拉取最新镜像
log_info "Pulling latest image: $COPAW_DOCKER_IMAGE"
if docker pull "$COPAW_DOCKER_IMAGE"; then
  log_success "Docker image updated successfully"
else
  log_warning "Failed to pull from Docker Hub, trying Aliyun ACR mirror..."

  # 尝试阿里云 ACR 镜像
  ALIYUN_IMAGE="agentscope-registry.ap-southeast-1.cr.aliyuncs.com/agentscope/copaw:latest"

  IMAGE_TAG=$(echo "$COPAW_DOCKER_IMAGE" | cut -d':' -f2)
  if [ -n "$IMAGE_TAG" ] && [ "$IMAGE_TAG" != "latest" ]; then
    ALIYUN_IMAGE="agentscope-registry.ap-southeast-1.cr.aliyuncs.com/agentscope/copaw:$IMAGE_TAG"
  fi

  log_info "Trying Aliyun ACR mirror: $ALIYUN_IMAGE"
  if docker pull "$ALIYUN_IMAGE"; then
    docker tag "$ALIYUN_IMAGE" "$COPAW_DOCKER_IMAGE"
    log_success "Docker image updated from Aliyun ACR"
  else
    log_error "Failed to update Docker image"
    exit 1
  fi
fi

# 重新启动容器
log_info "Starting container with updated image..."
bash ~/plugins-config/copaw-docker/scripts/start.sh

log_success "CoPaw Docker updated successfully"