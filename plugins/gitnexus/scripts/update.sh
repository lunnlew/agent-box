#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  # 如果不在容器内，定义简化版日志函数
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# 获取插件定义目录（支持容器内和本地两种环境）
if [ -n "$PLUGINS_DEF_DIR" ]; then
  SCRIPT_DIR="$PLUGINS_DEF_DIR/gitnexus/scripts"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

NPM_REGISTRY="${NPM_REGISTRY:-https://registry.npmmirror.com}"

log_info "Updating GitNexus..."

# 停止容器
docker stop gitnexus-bridge gitnexus-web 2>/dev/null || true
docker rm gitnexus-bridge gitnexus-web 2>/dev/null || true

# 更新源代码
cd ~/gitnexus-src && {
  git fetch origin
  git checkout main 2>/dev/null || true
  git pull origin main || true
}

# 重新构建镜像（包含最新补丁）
log_info "Rebuilding GitNexus Docker image..."
docker build -t gitnexus-runner:latest -f "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR/.." || {
  log_warning "Docker image rebuild failed"
}

# 获取 host 数据目录路径
AGENTBOX_MOUNT=$(get_mount_source agentbox /home/agent 2>/dev/null)
if [ -z "$AGENTBOX_MOUNT" ]; then
  AGENTBOX_MOUNT="$HOME"
fi
GITNEXUS_SRC_PATH="${AGENTBOX_MOUNT}/gitnexus-src"

# 重新构建 Web UI
log_info "Rebuilding gitnexus-shared..."
docker run --rm \
  -v "${GITNEXUS_SRC_PATH}:/app" \
  -w /app/gitnexus-shared \
  -e NPM_REGISTRY="${NPM_REGISTRY}" \
  gitnexus-runner:latest \
  bash -c "npm config set registry ${NPM_REGISTRY} && npm install && npm run build" || {
  log_warning "gitnexus-shared rebuild failed"
}

log_info "Rebuilding gitnexus-web..."
docker run --rm \
  -v "${GITNEXUS_SRC_PATH}:/app" \
  -w /app/gitnexus-web \
  -e NPM_REGISTRY="${NPM_REGISTRY}" \
  gitnexus-runner:latest \
  bash -c "npm config set registry ${NPM_REGISTRY} && npm install && npm run build" || {
  log_warning "gitnexus-web rebuild failed"
}

# 验证构建结果
if [ -f ~/gitnexus-src/gitnexus-web/dist/index.html ]; then
  log_success "GitNexus Web UI rebuilt successfully!"
else
  log_warning "Web UI build incomplete - may need manual rebuild"
fi

log_success "GitNexus updated. Run 'agentbox start gitnexus' to restart."