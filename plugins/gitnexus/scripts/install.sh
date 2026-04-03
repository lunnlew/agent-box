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

log_info "Installing GitNexus..."

# 构建 GitNexus 专用镜像（基于 Ubuntu 24.04，GLIBC 2.39）
# 构建上下文为插件根目录，以包含 patch 文件
log_info "Building GitNexus Docker image..."
docker build -t gitnexus-runner:latest -f "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR/.."

# 创建数据目录
mkdir -p ~/.gitnexus

# 克隆源码
log_info "Cloning GitNexus repository..."
if [ -d ~/gitnexus-src ]; then
  cd ~/gitnexus-src
  git pull || true
else
  git clone https://github.com/abhigyanpatwari/GitNexus.git ~/gitnexus-src
fi

# 自动构建 Web UI
log_info "Building GitNexus Web UI (this may take a few minutes)..."

# 获取 host 数据目录路径（用于 Docker 挂载）
AGENTBOX_MOUNT=$(get_mount_source agentbox /home/agent 2>/dev/null)
if [ -z "$AGENTBOX_MOUNT" ]; then
  # 回退：使用容器内路径（需要通过 agentbox 容器挂载）
  AGENTBOX_MOUNT="$HOME"
  log_warning "Could not detect host path, using container path"
fi

GITNEXUS_SRC_PATH="${AGENTBOX_MOUNT}/gitnexus-src"

# 构建 gitnexus-shared（依赖库）
log_info "Building gitnexus-shared..."
docker run --rm \
  -v "${GITNEXUS_SRC_PATH}:/app" \
  -w /app/gitnexus-shared \
  -e NPM_REGISTRY="${NPM_REGISTRY}" \
  gitnexus-runner:latest \
  bash -c "npm config set registry ${NPM_REGISTRY} && npm install && npm run build" || {
    log_warning "gitnexus-shared build failed, Web UI may not work properly"
  }

# 构建 gitnexus-web（前端）
log_info "Building gitnexus-web..."
docker run --rm \
  -v "${GITNEXUS_SRC_PATH}:/app" \
  -w /app/gitnexus-web \
  -e NPM_REGISTRY="${NPM_REGISTRY}" \
  gitnexus-runner:latest \
  bash -c "npm config set registry ${NPM_REGISTRY} && npm install && npm run build" || {
    log_warning "gitnexus-web build failed, Web UI may not work properly"
  }

# 验证构建结果
if [ -f ~/gitnexus-src/gitnexus-web/dist/index.html ]; then
  log_success "GitNexus Web UI built successfully!"
else
  log_warning "Web UI build incomplete - you may need to rebuild manually"
  log_info "See post_install instructions for manual build steps"
fi

log_success "GitNexus installed successfully"
log_info "Run 'agentbox start gitnexus' to start services"