#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# CoPaw Docker 安装脚本

log_info "Installing CoPaw Docker..."

# 设置镜像源（支持国内镜像）
COPAW_DOCKER_IMAGE=${COPAW_DOCKER_IMAGE:-agentscope/copaw:latest}

log_info "Pulling Docker image: $COPAW_DOCKER_IMAGE"

# 拉取镜像
if docker pull "$COPAW_DOCKER_IMAGE"; then
  log_success "Docker image pulled successfully"
else
  log_warning "Failed to pull from Docker Hub, trying Aliyun ACR mirror..."

  # 尝试阿里云 ACR 镜像
  ALIYUN_IMAGE="agentscope-registry.ap-southeast-1.cr.aliyuncs.com/agentscope/copaw:latest"

  # 从镜像 tag 提取版本
  IMAGE_TAG=$(echo "$COPAW_DOCKER_IMAGE" | cut -d':' -f2)
  if [ -n "$IMAGE_TAG" ] && [ "$IMAGE_TAG" != "latest" ]; then
    ALIYUN_IMAGE="agentscope-registry.ap-southeast-1.cr.aliyuncs.com/agentscope/copaw:$IMAGE_TAG"
  fi

  log_info "Trying Aliyun ACR mirror: $ALIYUN_IMAGE"
  if docker pull "$ALIYUN_IMAGE"; then
    # 重新标记为官方镜像名称
    docker tag "$ALIYUN_IMAGE" "$COPAW_DOCKER_IMAGE"
    log_success "Docker image pulled from Aliyun ACR and tagged successfully"
  else
    log_error "Failed to pull Docker image from both sources"
    exit 1
  fi
fi

# 创建 Docker volumes（如果不存在）
log_info "Creating Docker volumes..."
docker volume create copaw-data 2>/dev/null || true
docker volume create copaw-secrets 2>/dev/null || true

log_success "CoPaw Docker installation completed"