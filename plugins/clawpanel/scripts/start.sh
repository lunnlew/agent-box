#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# ClawPanel 启动脚本

CLAWPANEL_PORT="${CLAWPANEL_PORT:-1420}"

cd $HOME/tools/clawpanel && npm run serve -- --port ${CLAWPANEL_PORT}