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

# 获取 agentbox 容器的 /host-share 挂载源路径（主机路径）
HOST_SHARE_SOURCE=$(docker inspect agentbox --format '{{range .Mounts}}{{if eq .Destination "/host-share"}}{{.Source}}{{end}}{{end}}')

if [ -z "$HOST_SHARE_SOURCE" ]; then
  log_warning "无法获取 host-share 挂载源，使用默认路径"
  HOST_SHARE_SOURCE="$HOME"
fi

log_info "检测到的 host-share 源路径: $HOST_SHARE_SOURCE"

# 将路径转换为 Docker 兼容格式
# Docker Desktop Linux VM 格式 (/host_mnt/d/path 或 /run/desktop/mnt/host/d/path) - 已经是 Linux 格式，直接使用
# Windows 格式 (D:/path 或 D:\path) - 需要转换为 /d/path 格式
if [[ "$HOST_SHARE_SOURCE" =~ ^/host_mnt/ || "$HOST_SHARE_SOURCE" =~ ^/run/desktop/mnt/host/ ]]; then
  # Docker Desktop Linux VM 格式，直接使用
  log_info "使用 Docker Desktop Linux VM 格式路径"
elif [[ "$HOST_SHARE_SOURCE" =~ ^[A-Za-z]: ]]; then
  # Windows 格式 (D:/path 或 D:\path)，转换为 /d/path 格式
  HOST_SHARE_SOURCE=$(echo "$HOST_SHARE_SOURCE" | tr "\\" "/" | sed "s|^\([A-Za-z]\):|/\L\1|")
  log_info "转换 Windows 路径为 Linux 格式: $HOST_SHARE_SOURCE"
else
  # 其他格式（可能是 Linux 原生路径），清理多余斜杠
  HOST_SHARE_SOURCE=$(echo "$HOST_SHARE_SOURCE" | tr -s "/")
fi

log_info "Host share source (final): $HOST_SHARE_SOURCE"

# 构建 docker run 命令
DOCKER_RUN_CMD="docker run -d \
  --name copaw-docker \
  -p 127.0.0.1:${COPAW_DOCKER_PORT}:8088 \
  -v copaw-data:/app/working \
  -v copaw-secrets:/app/working.secret \
  -v ${HOST_SHARE_SOURCE}:/host-share"

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
  log_info "Host share mounted at: /host-share"
else
  log_error "Failed to start CoPaw Docker. Check logs: docker logs copaw-docker"
  exit 1
fi