#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# CoPaw 安装后配置

log_info "Initializing CoPaw..."
copaw init --defaults --accept-security || true

COPAW_PORT="${COPAW_PORT:-8088}"

echo ""
echo "============================================"
echo "  CoPaw 安装完成!"
echo "============================================"
echo ""
echo "访问地址：http://localhost:${COPAW_PORT}"
echo "配置目录：~/.copaw"
echo ""
echo "常用命令:"
echo "  copaw app     # 启动 Web 界面"
echo "  copaw init    # 初始化配置"
echo "============================================"
echo ""