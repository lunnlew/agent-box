#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
}

log_info "Uninstalling AgentBox Dashboard..."

# 停止服务进程
pkill -f "board-server" 2>/dev/null || true
pkill -f "start-board" 2>/dev/null || true

rm -rf ~/supervisor/board.conf 2>/dev/null || true
rm -rf ~/supervisor/board.sh 2>/dev/null || true

# 清理日志
rm -f ~/logs/board.log 2>/dev/null || true

log_success "Dashboard uninstalled"