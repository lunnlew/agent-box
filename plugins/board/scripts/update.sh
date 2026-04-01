#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
}

log_info "Updating AgentBox Dashboard..."

# 重启服务（如果正在运行）
pkill -f "board-server" 2>/dev/null || true
sleep 1

log_success "Dashboard updated successfully"