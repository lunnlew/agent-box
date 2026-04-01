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

log_info "Uninstalling GitNexus..."

# 停止并移除容器
docker stop gitnexus-bridge gitnexus-web 2>/dev/null || true
docker rm gitnexus-bridge gitnexus-web 2>/dev/null || true

# 移除镜像
docker rmi gitnexus-runner:latest 2>/dev/null || true

# 清理数据
rm -rf ~/gitnexus-src 2>/dev/null || true

log_info "User indexes preserved in ~/.gitnexus"
log_info "To fully clean: rm -rf ~/.gitnexus"

log_success "GitNexus uninstalled"