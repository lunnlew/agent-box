#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}


DEERFLOW_PORT="${DEERFLOW_PORT:-2026}"

echo ""
echo "============================================"
echo "  DeerFlow 安装完成!"
echo "============================================"
echo ""
echo "访问地址：http://localhost:${DEERFLOW_PORT}"
echo "安装目录：~/deer-flow"
echo ""
echo "配置文件："
echo "  ~/deer-flow/config.yaml - 模型和沙箱配置"
echo "  ~/deer-flow/.env - API Keys 等环境变量"
echo ""
echo "环境变量："
echo "  export DEERFLOW_PORT=2026"
echo "  export DASHSCOPE_API_KEY=your-key"
echo ""
echo "启动服务："
echo "  agentbox start deer-flow"
echo ""
echo "或手动运行："
echo "  cd ~/deer-flow && make docker-start"
echo "============================================"
echo ""