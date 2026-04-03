#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

log_info "Updating DeerFlow..."

cd ~/deer-flow 2>/dev/null || {
  log_error "DeerFlow not installed"
  exit 1
}

# 备份配置
if [ -f config.yaml ]; then
  cp config.yaml config.yaml.bak
fi
if [ -f .env ]; then
  cp .env .env.bak
fi

# Git pull 更新
git fetch origin
git checkout main 2>/dev/null || git checkout master 2>/dev/null || true
git pull origin $(git branch --show-current 2>/dev/null || echo "main")

# 恢复配置
if [ -f config.yaml.bak ]; then
  mv config.yaml.bak config.yaml
fi
if [ -f .env.bak ]; then
  mv .env.bak .env
fi

# 修复权限
chown -R agent:agent ~/.docker 2>/dev/null || true
chmod -R 755 ~/.docker 2>/dev/null || true
mkdir -p ~/.docker/buildx/activity
chown -R agent:agent ~/.docker/buildx 2>/dev/null || true
chmod -R 755 ~/.docker/buildx 2>/dev/null || true

# 重启服务
make docker-stop 2>/dev/null || true
make docker-init 2>/dev/null || true
make docker-start &

log_success "DeerFlow updated"