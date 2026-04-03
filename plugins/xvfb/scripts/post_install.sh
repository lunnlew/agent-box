#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# Xvfb 安装后提示

echo ""
echo "============================================"
echo "  Xvfb 安装完成!"
echo "============================================"
echo ""
echo "显示环境：DISPLAY=:99"
echo "脚本目录：~/plugins-config/xvfb"
echo ""
echo "注意：此插件仅提供虚拟显示环境"
echo "各 GUI 应用需自行启动 x11vnc + noVNC 实例"
echo "============================================"
echo ""