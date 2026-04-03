#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}


BOARD_PORT="${BOARD_PORT:-8888}"

echo ""
echo "============================================"
echo "  AgentBox Dashboard 安装完成!"
echo "============================================"
echo ""
echo "访问地址：http://localhost:${BOARD_PORT}"
echo "配置目录：~/plugins-config/board/"
echo "日志文件：~/logs/board.log"
echo "============================================"
echo ""