#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# ClawPanel 安装后提示

CLAWPANEL_PORT="${CLAWPANEL_PORT:-1420}"

echo ""
echo "============================================"
echo "  ClawPanel 安装完成!"
echo "============================================"
echo ""
echo "访问地址：http://localhost:${CLAWPANEL_PORT}"
echo "安装目录：~/tools/clawpanel"
echo ""
echo "环境变量:"
echo "  export CLAWPANEL_PORT=1420"
echo ""
echo "启动服务:"
echo "  agentbox start clawpanel"
echo ""
echo "或直接运行:"
echo "  cd ~/tools/clawpanel && npm run serve"
echo "============================================"
echo ""