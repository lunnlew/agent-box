#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# ClawPort UI 启动脚本

CLAWPORT_PORT="${CLAWPORT_PORT:-3000}"
WORKSPACE_PATH="${WORKSPACE_PATH:-$HOME/.openclaw/workspace}"
OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-}"

cd $HOME
WORKSPACE_PATH=${WORKSPACE_PATH} \
OPENCLAW_BIN=$HOME/tools/bin/openclaw \
OPENCLAW_GATEWAY_PORT=${OPENCLAW_GATEWAY_PORT} \
PORT=${CLAWPORT_PORT} \
NEXT_PUBLIC_CLAWPORT_PORT=${CLAWPORT_PORT} \
clawport dev