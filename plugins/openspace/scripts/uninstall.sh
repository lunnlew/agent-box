#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

log_info "Uninstalling OpenSpace..."

# 停止服务
if pgrep -f "openspace-dashboard" >/dev/null 2>&1; then
  log_info "Stopping running services..."
  pkill -f "openspace-dashboard" 2>/dev/null || true
fi
if pgrep -f "vite.*openspace" >/dev/null 2>&1; then
  pkill -f "vite.*openspace" 2>/dev/null || true
fi

sleep 2

# 删除源码目录（保留用户数据）
log_info "Removing source directory..."
rm -rf ~/openspace-src

# 询问是否删除用户数据
log_warning "User data preserved at ~/.openspace"
log_info "To remove user data, run: rm -rf ~/.openspace"

log_success "OpenSpace uninstalled successfully"