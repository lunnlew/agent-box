#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}


OPENCLAW_MANAGER_NOVNC_PORT="${OPENCLAW_MANAGER_NOVNC_PORT:-6081}"

echo ""
echo "============================================"
echo "  OpenClaw Manager 安装完成!"
echo "============================================"
echo ""
echo "访问地址：http://localhost:${OPENCLAW_MANAGER_NOVNC_PORT}/vnc.html (独立 noVNC 实例)"
echo "安装目录：~/tools/appimages/OpenClaw-Manager"
echo "配置目录：~/.openclaw-manager"
echo ""
echo "注意：使用独立 Xvfb 显示环境 (:100)"
echo "============================================"
echo ""