#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# OpenClaw Dashboard 安装后提示


log_info "Initializing OpenClaw Dashboard..."

DASHBOARD_PATH="$HOME/tools/openclaw-dashboard"
DASHBOARD_PORT="${DASHBOARD_PORT:-7000}"
WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME}"

echo ""
echo "============================================"
echo "  OpenClaw Dashboard 安装完成!"
echo "============================================"
echo ""
echo "访问地址：http://localhost:${DASHBOARD_PORT}"
echo "安装目录：~/tools/openclaw-dashboard"
echo ""
echo "环境变量:"
echo "  export DASHBOARD_PORT=7000"
echo "  export WORKSPACE_DIR=$HOME"
echo "  export OPENCLAW_DIR=$HOME/.openclaw"
echo "  export OPENCLAW_AGENT=main"
echo ""
echo "启动服务:"
echo "  agentbox start openclaw-dashboard"
echo ""
echo "或直接运行:"
echo "  cd ~/tools/openclaw-dashboard && node server.js"
echo ""
echo "⚠️ 重要：首次启动后会显示 Recovery token，请保存!"
echo "============================================"
echo ""