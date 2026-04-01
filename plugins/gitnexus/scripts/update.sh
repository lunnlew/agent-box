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

log_success "GitNexus updated. Run 'agentbox start gitnexus' to restart."