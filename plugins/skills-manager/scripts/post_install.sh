#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}


SKILLS_MANAGER_NOVNC_PORT="${SKILLS_MANAGER_NOVNC_PORT:-6080}"

echo ""
echo "============================================"
echo "  Skills Manager 安装完成!"
echo "============================================"
echo ""
echo "访问地址：http://localhost:${SKILLS_MANAGER_NOVNC_PORT}/vnc.html (独立 noVNC 实例)"
echo "安装目录：~/tools/appimages/Skills-Manager"
echo "配置目录：~/.skills-manager"
echo ""
echo "注意：使用独立 Xvfb 显示环境 (:99)"
echo "============================================"
echo ""