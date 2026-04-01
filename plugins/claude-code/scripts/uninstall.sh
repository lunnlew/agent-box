#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

log_info "Uninstalling Claude Code..."

# 停止进程
pkill -f "claude" 2>/dev/null || true

# 移除二进制文件
rm -f ~/.local/bin/claude 2>/dev/null || true

# 清理安装目录
rm -rf ~/.local/share/claude 2>/dev/null || true

# 清理配置文件
rm -f ~/.claude.json 2>/dev/null || true

# 清理缓存
rm -rf ~/.cache/claude 2>/dev/null || true

log_info "User data preserved in ~/.claude"

log_success "Claude Code uninstalled"