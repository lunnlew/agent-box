#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# VS Code Server 启动脚本

VSCODE_PORT="${VSCODE_PORT:-8080}"

exec code-server --bind-addr 0.0.0.0:${VSCODE_PORT} --auth password --disable-telemetry $HOME