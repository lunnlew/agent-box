#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# Xvfb 卸载脚本


log_info "Uninstalling Xvfb..."

# 停止服务
pkill -f "Xvfb.*:99" 2>/dev/null || true

# 清理临时文件
rm -rf /tmp/.X11-unix/X99 2>/dev/null || true

rm -rf ~/supervisor/xvfb.conf 2>/dev/null || true
rm -rf ~/supervisor/xvfb.sh 2>/dev/null || true

log_success "Xvfb uninstalled"