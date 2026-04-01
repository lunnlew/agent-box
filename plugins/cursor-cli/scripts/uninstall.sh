#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
}

log_info "Uninstalling Cursor CLI..."

# 停止进程
pkill -f "agent" 2>/dev/null || true

# 移除二进制文件
rm -f ~/.local/bin/agent 2>/dev/null || true
rm -f /usr/local/bin/agent 2>/dev/null || true
rm -f ~/.cargo/bin/agent 2>/dev/null || true

# 清理缓存
rm -rf ~/.cache/cursor 2>/dev/null || true

log_info "User data preserved in ~/.cursor"

log_success "Cursor CLI uninstalled"