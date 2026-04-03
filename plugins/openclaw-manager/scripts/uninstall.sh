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

log_info "Uninstalling OpenClaw Manager..."

# 停止进程
pkill -f "OpenClaw-Manager" 2>/dev/null || true
pkill -f "x11vnc.*5901" 2>/dev/null || true
pkill -f "websockify.*6081" 2>/dev/null || true

# 清理 Supervisor 配置
rm -rf ~/supervisor/openclaw-manager.conf 2>/dev/null || true
rm -rf ~/supervisor/openclaw-manager.sh 2>/dev/null || true

# 清理安装目录
rm -rf ~/tools/appimages/OpenClaw-Manager 2>/dev/null || true

# ⚠️ 保留用户配置
# rm -rf ~/.openclaw-manager 2>/dev/null || true

log_success "OpenClaw Manager uninstalled"