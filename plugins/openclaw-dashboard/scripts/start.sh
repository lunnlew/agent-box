#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# OpenClaw Dashboard 启动脚本

DASHBOARD_PORT="${DASHBOARD_PORT:-7000}"
WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME}"
OPENCLAW_AGENT="${OPENCLAW_AGENT:-main}"

cd $HOME/tools/openclaw-dashboard

DASHBOARD_PORT=${DASHBOARD_PORT} \
WORKSPACE_DIR=${WORKSPACE_DIR} \
OPENCLAW_DIR=$HOME/.openclaw \
OPENCLAW_AGENT=${OPENCLAW_AGENT} \
DASHBOARD_ALLOW_HTTP=true \
node server.js