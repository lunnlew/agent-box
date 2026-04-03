#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
}

log_info "Uninstalling Web Terminal..."

# 停止进程
pkill -f "ttyd" 2>/dev/null || true

# 移除二进制文件
rm -f $HOME/tools/bin/ttyd 2>/dev/null || true

rm -rf ~/supervisor/web-terminal.conf 2>/dev/null || true
rm -rf ~/supervisor/web-terminal.sh 2>/dev/null || true

log_success "Web Terminal uninstalled"