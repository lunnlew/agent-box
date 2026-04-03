#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# Superset 安装后提示

SUPERSET_NOVNC_PORT="${SUPERSET_NOVNC_PORT:-6081}"

echo ""
echo "============================================"
echo "  Superset 安装完成!"
echo "============================================"
echo ""
echo "访问地址：http://localhost:${SUPERSET_NOVNC_PORT}/vnc.html"
echo "安装目录：~/tools/appimages/Superset"
echo "配置目录：~/.superset"
echo ""
echo "依赖服务：xvfb (仅复用 Xvfb 虚拟显示)"
echo "============================================"
echo ""