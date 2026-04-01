#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# Web Terminal 启动脚本

WEB_TERMINAL_PORT="${WEB_TERMINAL_PORT:-7681}"

exec ttyd --port ${WEB_TERMINAL_PORT} --writable --reconnect bash