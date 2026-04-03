#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}


# OpenClaw Manager 停止脚本

OPENCLAW_MANAGER_NOVNC_PORT="${OPENCLAW_MANAGER_NOVNC_PORT:-6081}"
OPENCLAW_MANAGER_VNC_PORT="${OPENCLAW_MANAGER_VNC_PORT:-5901}"
DISPLAY_NUM=100

echo "Stopping OpenClaw Manager..."

# 停止应用进程
pkill -f "OpenClaw-Manager" 2>/dev/null || true

# 停止 x11vnc
pkill -f "x11vnc.*${OPENCLAW_MANAGER_VNC_PORT}" 2>/dev/null || true

# 停止 websockify/noVNC
pkill -f "websockify.*${OPENCLAW_MANAGER_NOVNC_PORT}" 2>/dev/null || true

# 停止 Xvfb
pkill -f "Xvfb :${DISPLAY_NUM}" 2>/dev/null || true

echo "OpenClaw Manager stopped"