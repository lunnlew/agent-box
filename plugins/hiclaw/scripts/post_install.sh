#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# HiClaw 安装后提示

HICLAW_PORT_GATEWAY="${HICLAW_PORT_GATEWAY:-18080}"
HICLAW_PORT_CONSOLE="${HICLAW_PORT_CONSOLE:-18001}"
HICLAW_PORT_ELEMENT_WEB="${HICLAW_PORT_ELEMENT_WEB:-18088}"

echo ""
echo "============================================"
echo "  HiClaw 安装完成!"
echo "============================================"
echo ""
echo "服务端口:"
echo "  Gateway:  http://localhost:${HICLAW_PORT_GATEWAY}"
echo "  Console:  http://localhost:${HICLAW_PORT_CONSOLE}"
echo "  Element:  http://localhost:${HICLAW_PORT_ELEMENT_WEB}"
echo ""
echo "启动服务:"
echo "  agentbox start hiclaw"
echo ""
echo "或使用 Docker 命令:"
echo "  docker start hiclaw-manager"
echo "============================================"
echo ""