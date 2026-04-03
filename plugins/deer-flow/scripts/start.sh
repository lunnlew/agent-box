#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# ============================================
# DeerFlow 启动脚本 - 适配 AgentBox 环境 (WSL2 + Docker Desktop)
# ============================================

# 不使用 set -e，避免命令失败导致脚本退出
# set -e

DEERFLOW_DIR="$HOME/deer-flow"
cd "$DEERFLOW_DIR"

echo "=========================================="
echo "  Starting DeerFlow Docker Development"
echo "=========================================="
echo ""

# 获取 Windows 主机路径 - 使用共享函数处理 Docker Desktop WSL2 路径转换
# 计算相对于 /home/agent 的相对路径
get_windows_path() {
    local container_path="$1"
    local rel_path=""
    local home="${HOME:-/home/agent}"

    # 计算相对路径
    if [[ "$container_path" == "$home/"* ]]; then
        rel_path="${container_path#$home/}"
    fi

    # 使用共享函数获取主机路径
    get_host_mount_path agentbox /home/agent "$rel_path"
}

# 获取 agentbox 容器中所有 /host-share 相关的挂载信息
# 使用共享函数（返回 VOLUME_ARGS 和 HOST_SHARE_MOUNTS 变量）
get_inherited_mounts agentbox /host-share

# 设置环境变量 - 使用继承的挂载信息
export DEER_FLOW_ROOT=$(get_windows_path "$DEERFLOW_DIR")
export DEER_FLOW_HOST_SHARE_MOUNTS="$HOST_SHARE_MOUNTS"
export DEER_FLOW_HOST_SHARE_VOLUME_ARGS="$VOLUME_ARGS"
export DEER_FLOW_CONFIG_PATH="$DEER_FLOW_ROOT/config.yaml"
export DEER_FLOW_EXTENSIONS_CONFIG_PATH="$DEER_FLOW_ROOT/extensions_config.json"
export DEER_FLOW_HOME="$DEER_FLOW_ROOT/backend/.deer-flow"
export DEER_FLOW_REPO_ROOT="$DEER_FLOW_ROOT"
export DEER_FLOW_FRONTEND_SRC="$DEER_FLOW_ROOT/frontend/src"
export DEER_FLOW_FRONTEND_PUBLIC="$DEER_FLOW_ROOT/frontend/public"
export DEER_FLOW_FRONTEND_NEXT_CONFIG="$DEER_FLOW_ROOT/frontend/next.config.js"
export DEER_FLOW_LOGS="$DEER_FLOW_ROOT/logs"
export DEER_FLOW_BACKEND="$DEER_FLOW_ROOT/backend/"
export DEER_FLOW_SKILLS="$DEER_FLOW_ROOT/skills"
export DEERFLOW_PORT="${DEERFLOW_PORT:-2026}"
export BETTER_AUTH_SECRET=deerflow-secret-key-$(date +%s)

# 加载 .env 文件中的环境变量（供 docker-compose 使用）
if [ -f "$DEERFLOW_DIR/.env" ]; then
    echo "Loading environment variables from .env..."
    set -a
    source "$DEERFLOW_DIR/.env"
    set +a
    echo "Loaded environment variables:"
    grep -v "^#" "$DEERFLOW_DIR/.env" | grep "=" | head -5
fi

# 确保 frontend/.env 存在（Next.js 前端需要）
if [ ! -f "$DEERFLOW_DIR/frontend/.env" ]; then
    echo "Creating frontend/.env..."
    mkdir -p "$DEERFLOW_DIR/frontend"
    cat > "$DEERFLOW_DIR/frontend/.env" << 'FRONTENDENVEOF'
# DeerFlow Frontend 环境配置
# Backend API URLs (optional, uses nginx proxy by default)
# NEXT_PUBLIC_BACKEND_BASE_URL="http://localhost:8001"
# NEXT_PUBLIC_LANGGRAPH_BASE_URL="http://localhost:2024"
FRONTENDENVEOF
fi

echo "DEER_FLOW_ROOT=$DEER_FLOW_ROOT"
echo "DEERFLOW_PORT=$DEERFLOW_PORT"
echo ""

# 修复 Docker 配置权限
mkdir -p ~/.docker
chown -R agent:agent ~/.docker 2>/dev/null || true
chmod 755 ~/.docker 2>/dev/null || true
echo '{}' > ~/.docker/config.json
chown agent:agent ~/.docker/config.json 2>/dev/null || true
chmod 644 ~/.docker/config.json 2>/dev/null || true

# 修复 buildx 目录权限（包括所有子文件）
# Docker buildx 运行时会以 root 创建 activity 文件，需要修复
mkdir -p ~/.docker/buildx/activity
chown -R agent:agent ~/.docker/buildx 2>/dev/null || true
chmod -R 755 ~/.docker/buildx 2>/dev/null || true
chmod -R 644 ~/.docker/buildx/activity/* 2>/dev/null || true

# 检查 buildx builder
echo "Checking buildx builder..."
if ! docker buildx ls 2>/dev/null | grep -q "agentbox-builder"; then
    echo "Creating buildx builder..."
    docker buildx rm default 2>/dev/null || true
    docker buildx create --use --bootstrap --name agentbox-builder >/dev/null 2>&1
fi

# 设置默认 builder
docker buildx use agentbox-builder 2>/dev/null || true

# 再次修复权限（buildx use 可能创建新文件）
chown -R agent:agent ~/.docker/buildx 2>/dev/null || true
chmod -R 755 ~/.docker/buildx 2>/dev/null || true

# 配置 Docker 镜像加速（解决 Docker Hub 拉取超时问题）
# 使用阿里云 Docker 镜像加速器
echo "Configuring Docker registry mirrors..."

# 设置 Docker Hub 镜像代理（如果配置了）
if [ -n "$DOCKER_REGISTRY_MIRROR" ]; then
    echo "Using Docker registry mirror: $DOCKER_REGISTRY_MIRROR"
fi

# 尝试从国内镜像预拉取基础镜像（加速构建）
echo "Pre-pulling base images from China mirrors..."
docker pull docker.m.daocloud.io/library/python:3.12-slim 2>/dev/null && \
    docker tag docker.m.daocloud.io/library/python:3.12-slim python:3.12-slim || true
docker pull docker.m.daocloud.io/library/node:22-alpine 2>/dev/null && \
    docker tag docker.m.daocloud.io/library/node:22-alpine node:22-alpine || true
docker pull docker.m.daocloud.io/library/nginx:alpine 2>/dev/null && \
    docker tag docker.m.daocloud.io/library/nginx:alpine nginx:alpine || true
docker pull docker.m.daocloud.io/library/docker:cli 2>/dev/null && \
    docker tag docker.m.daocloud.io/library/docker:cli docker:cli || true
# ghcr.io 通常可以直接访问
docker pull ghcr.io/astral-sh/uv:0.7.20 2>/dev/null || true

echo ""

# 备份并修改 Dockerfile，使用本地已有镜像
echo "Patching Dockerfiles to use local images..."
cd "$DEERFLOW_DIR"

# 备份 backend Dockerfile
if [ ! -f backend/Dockerfile.bak ]; then
    cp backend/Dockerfile backend/Dockerfile.bak 2>/dev/null || true
fi

# 修改 backend Dockerfile - 使用本地镜像名称（不指定镜像源）
sed -e 's/FROM docker.m.daocloud.io\/library\/python:3.12-slim/FROM python:3.12-slim/' \
    -e 's/COPY --from=docker.m.daocloud.io\/library\/docker:cli/COPY --from=docker:cli/' \
    -e 's/COPY --from=ghcr.io\/astral-sh\/uv:0.7.20/COPY --from=ghcr.io\/astral-sh\/uv:0.7.20/' \
    backend/Dockerfile.bak > backend/Dockerfile 2>/dev/null || true

# 备份 frontend Dockerfile
if [ ! -f frontend/Dockerfile.bak ]; then
    cp frontend/Dockerfile frontend/Dockerfile.bak 2>/dev/null || true
fi

# 修改 frontend Dockerfile - 使用本地镜像名称
sed -e 's/FROM docker.m.daocloud.io\/library\/node:22-alpine/FROM node:22-alpine/' \
    frontend/Dockerfile.bak > frontend/Dockerfile 2>/dev/null || true

echo "Dockerfiles patched successfully"
echo ""

# 修复 deer-flow 目录权限
chown -R agent:agent ~/deer-flow 2>/dev/null || true
chmod -R 755 ~/deer-flow/docker 2>/dev/null || true

# 检测沙箱模式
sandbox_mode=$(grep -A 5 "^sandbox:" config.yaml 2>/dev/null | grep "use:" | head -1 | awk '{print $2}')
echo "Detected sandbox mode: $sandbox_mode"
echo ""

# 停止现有容器
echo "Stopping existing containers..."
docker compose -p deer-flow-dev -f docker/docker-compose-dev-modified.yaml down 2>/dev/null || true

# 生成修改后的 docker-compose 文件（路径转换 + 端口配置）
echo "Generating modified docker-compose file..."
cd docker
python3 ~/plugins-config/deer-flow/scripts/modify-compose.py

# 启动服务
echo "Building and starting containers..."
# 启用 BuildKit 以支持 --mount=type=cache
export DOCKER_BUILDKIT=1
export BUILDKIT_PROGRESS=plain
docker compose -p deer-flow-dev -f docker-compose-dev-modified.yaml up --build -d --remove-orphans

echo ""
echo "=========================================="
echo "  DeerFlow Docker is starting!"
echo "=========================================="
echo ""
echo "  Application: http://localhost:${DEERFLOW_PORT}"
echo "  API Gateway: http://localhost:${DEERFLOW_PORT}/api/*"
echo "  LangGraph:   http://localhost:${DEERFLOW_PORT}/api/langgraph/*"
echo ""
echo "  View logs: docker logs -f deer-flow-nginx"
echo "  Stop:      make docker-stop"
echo ""
