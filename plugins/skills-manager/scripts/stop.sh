#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}


# Skills Manager 停止脚本

SKILLS_MANAGER_NOVNC_PORT="${SKILLS_MANAGER_NOVNC_PORT:-6080}"
SKILLS_MANAGER_VNC_PORT="${SKILLS_MANAGER_VNC_PORT:-5900}"
DISPLAY_NUM=99

echo "Stopping Skills Manager..."

# 停止应用进程
pkill -f "Skills-Manager" 2>/dev/null || true

# 停止 x11vnc
pkill -f "x11vnc.*${SKILLS_MANAGER_VNC_PORT}" 2>/dev/null || true

# 停止 websockify/noVNC
pkill -f "websockify.*${SKILLS_MANAGER_NOVNC_PORT}" 2>/dev/null || true

# 停止 Xvfb
pkill -f "Xvfb :${DISPLAY_NUM}" 2>/dev/null || true

echo "Skills Manager stopped"