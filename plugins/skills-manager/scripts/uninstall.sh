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

log_info "Uninstalling Skills Manager..."

# 停止进程
pkill -f "Skills-Manager" 2>/dev/null || true
pkill -f "x11vnc.*5900" 2>/dev/null || true
pkill -f "websockify.*6080" 2>/dev/null || true

# 清理 Supervisor 配置
rm -rf ~/supervisor/skills-manager.conf 2>/dev/null || true
rm -rf ~/supervisor/skills-manager.sh 2>/dev/null || true

# 清理安装目录
rm -rf ~/tools/appimages/Skills-Manager 2>/dev/null || true

# ⚠️ 保留用户配置
# rm -rf ~/.skills-manager 2>/dev/null || true

log_success "Skills Manager uninstalled"