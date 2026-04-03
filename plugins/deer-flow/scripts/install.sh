#!/bin/bash
set -e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

log_info "Cloning DeerFlow repository..."

# 检查是否已存在
if [ -d ~/deer-flow ]; then
  log_info "DeerFlow repository already exists, updating..."
  cd ~/deer-flow

  # 清理可能存在的 git lock 文件（之前操作中断可能导致）
  rm -f .git/index.lock .git/FETCH_HEAD 2>/dev/null || true

  # 修复 git 目录权限（可能被 root 创建）
  chown -R agent:agent .git 2>/dev/null || true

  git pull || log_warning "git pull failed, continuing..."
else
  log_info "Cloning DeerFlow from GitHub..."
  git clone https://github.com/bytedance/deer-flow.git ~/deer-flow
  cd ~/deer-flow
fi

# 切换到主分支
cd ~/deer-flow
git checkout main 2>/dev/null || git checkout master 2>/dev/null || true

# 修复目录权限
log_info "Fixing DeerFlow directory permissions..."
chown -R agent:agent ~/deer-flow 2>/dev/null || true
chmod -R 755 ~/deer-flow/docker 2>/dev/null || true

# 修复 Docker 配置目录权限
log_info "Fixing Docker config permissions..."
mkdir -p ~/.docker
chown -R agent:agent ~/.docker 2>/dev/null || true
chmod 755 ~/.docker 2>/dev/null || true

# 修复 config.json 权限
if [ ! -f ~/.docker/config.json ]; then
  echo '{}' > ~/.docker/config.json
fi
chown agent:agent ~/.docker/config.json 2>/dev/null || true
chmod 644 ~/.docker/config.json 2>/dev/null || true

# 修复 buildx 权限
mkdir -p ~/.docker/buildx/activity
chown -R agent:agent ~/.docker/buildx 2>/dev/null || true
chmod -R 755 ~/.docker/buildx 2>/dev/null || true

# 创建默认配置
log_info "Creating default configuration..."
cd ~/deer-flow
if [ ! -f config.yaml ]; then
  bash ~/plugins-config/deer-flow/scripts/init-config.sh ~/deer-flow
fi

# 运行 docker-init 预拉取镜像
log_info "Running docker-init..."
export DEER_FLOW_ROOT="$(bash ~/plugins-config/deer-flow/scripts/setup-docker-root.sh ~/deer-flow)"
log_info "DEER_FLOW_ROOT set to: $DEER_FLOW_ROOT"
make docker-init || log_warning "docker-init skipped (local sandbox mode)"

log_success "DeerFlow repository cloned to ~/deer-flow"