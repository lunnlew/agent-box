#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# CoPaw Docker 启动脚本

# 设置环境变量
COPAW_DOCKER_PORT=${COPAW_DOCKER_PORT:-8088}
COPAW_DOCKER_IMAGE=${COPAW_DOCKER_IMAGE:-agentscope/copaw:latest}

log_info "Starting CoPaw Docker on port $COPAW_DOCKER_PORT..."

# 检查容器是否已存在
if docker ps -a --filter name=copaw-docker -q | grep -q .; then
  # 容器存在，检查是否正在运行
  if docker ps --filter name=copaw-docker --filter status=running -q | grep -q .; then
    log_info "CoPaw Docker is already running"
    exit 0
  fi

  # 启动已存在的容器
  log_info "Starting existing CoPaw Docker container..."
  docker start copaw-docker

  sleep 3

  if docker ps --filter name=copaw-docker --filter status=running -q | grep -q .; then
    log_success "CoPaw Docker started successfully"
    exit 0
  else
    log_error "Failed to start CoPaw Docker. Check logs: docker logs copaw-docker"
    exit 1
  fi
fi

# 容器不存在，创建并启动
log_info "Creating and starting CoPaw Docker container..."

# 获取 agentbox 容器中所有 /host-share 相关的挂载信息
# 使用共享函数（返回 VOLUME_ARGS 和 HOST_SHARE_MOUNTS 变量）
get_inherited_mounts agentbox /host-share

log_info "Volume args: $VOLUME_ARGS"

# 构建 docker run 命令
DOCKER_RUN_CMD="docker run -d \
  --name copaw-docker \
  -p 127.0.0.1:${COPAW_DOCKER_PORT}:8088 \
  -v copaw-data:/app/working \
  -v copaw-secrets:/app/working.secret \
  ${VOLUME_ARGS}"

# 如果设置了 DASHSCOPE_API_KEY，传入环境变量
if [ -n "$DASHSCOPE_API_KEY" ]; then
  DOCKER_RUN_CMD="$DOCKER_RUN_CMD -e DASHSCOPE_API_KEY=${DASHSCOPE_API_KEY}"
fi

# 添加镜像名称
DOCKER_RUN_CMD="$DOCKER_RUN_CMD ${COPAW_DOCKER_IMAGE}"

# 执行启动命令
log_info "Executing: $DOCKER_RUN_CMD"
eval "$DOCKER_RUN_CMD"

sleep 5

# 检查容器状态
if docker ps --filter name=copaw-docker --filter status=running -q | grep -q .; then
  log_success "CoPaw Docker started successfully"
  log_info "Access CoPaw at: http://127.0.0.1:${COPAW_DOCKER_PORT}/"
  log_info "Host share mounts: ${HOST_SHARE_MOUNTS}"
else
  log_error "Failed to start CoPaw Docker. Check logs: docker logs copaw-docker"
  exit 1
fi