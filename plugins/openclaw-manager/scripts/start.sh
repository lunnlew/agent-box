#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# OpenClaw Manager 应用启动脚本
# 使用独立的 Xvfb 显示 (:100)，不依赖 xvfb 插件

# 获取插件定义目录（支持容器内和本地两种环境）
if [ -n "$PLUGINS_DEF_DIR" ]; then
  SCRIPT_DIR="$PLUGINS_DEF_DIR/openclaw-manager/scripts"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# 配置独立端口
OPENCLAW_MANAGER_NOVNC_PORT="${OPENCLAW_MANAGER_NOVNC_PORT:-6081}"
OPENCLAW_MANAGER_VNC_PORT="${OPENCLAW_MANAGER_VNC_PORT:-5901}"
DISPLAY_NUM=100  # 使用独立的 Xvfb 显示

# 设置环境变量
export DISPLAY=:${DISPLAY_NUM}
export GDK_BACKEND=x11
export NO_AT_BRIDGE=1

# 检查 Xvfb 是否运行在 :100
if ! pgrep -f "Xvfb :${DISPLAY_NUM}" > /dev/null 2>&1; then
    echo "Starting Xvfb on :${DISPLAY_NUM}..."
    mkdir -p /tmp/.X11-unix
    chmod 1777 /tmp/.X11-unix 2>/dev/null || true
    # 清理残留的 X11 socket 文件（容器重启后可能存在）
    rm -f /tmp/.X11-unix/X${DISPLAY_NUM} 2>/dev/null || true
    Xvfb :${DISPLAY_NUM} -screen 0 1920x1080x24 &
    sleep 2
    if ! pgrep -f "Xvfb :${DISPLAY_NUM}" > /dev/null 2>&1; then
        echo "ERROR: Failed to start Xvfb on :${DISPLAY_NUM}"
        exit 1
    fi
    echo "Xvfb started on :${DISPLAY_NUM}"
fi

echo "Using virtual display: :${DISPLAY_NUM}"

# 确保 X server 允许本地连接
xhost +local: 2>/dev/null || true

# 检查 AppImage 是否已提取
SQUASHFS_DIR=""
if [ -d ~/tools/appimages/OpenClaw-Manager/squashfs-root ]; then
    SQUASHFS_DIR=~/tools/appimages/OpenClaw-Manager/squashfs-root
elif [ -d ~/tools/appimages/squashfs-root ]; then
    SQUASHFS_DIR=~/tools/appimages/squashfs-root
fi

if [ -z "$SQUASHFS_DIR" ]; then
    echo "ERROR: Extracted AppImage not found"
    echo "Please reinstall the plugin with: agentbox install openclaw-manager --force"
    exit 1
fi

# 修复 AppImage 解压后的权限问题（squashfs 提取后文件属于 root，需要给所有用户权限）
echo "Fixing permissions on squashfs-root..."
chmod -R 755 "$SQUASHFS_DIR" 2>/dev/null || true
chmod +x "$SQUASHFS_DIR/AppRun" 2>/dev/null || true
if [ -f "$SQUASHFS_DIR/AppRun.wrapped" ]; then
    chmod +x "$SQUASHFS_DIR/AppRun.wrapped" 2>/dev/null || true
fi

# 启动独立的 x11vnc 实例（共享 DISPLAY 但不同端口）
echo "Starting x11vnc for OpenClaw Manager on port ${OPENCLAW_MANAGER_VNC_PORT}..."
# 先清理可能占用端口的旧进程
pkill -f "x11vnc.*${OPENCLAW_MANAGER_VNC_PORT}" 2>/dev/null || true
sleep 1
# 启动 x11vnc，使用 -noxdamage 和 -noxfixes 避免 X11 扩展问题
x11vnc -display :${DISPLAY_NUM} -forever -shared -rfbport ${OPENCLAW_MANAGER_VNC_PORT} -nopw -bg -noxdamage -noxfixes
sleep 2
# 检查 x11vnc 是否成功启动
if ! pgrep -f "x11vnc.*${OPENCLAW_MANAGER_VNC_PORT}" > /dev/null; then
    echo "ERROR: Failed to start x11vnc on port ${OPENCLAW_MANAGER_VNC_PORT}"
    exit 1
fi
echo "x11vnc started successfully"

# 启动独立的 noVNC 实例
echo "Starting noVNC for OpenClaw Manager on port ${OPENCLAW_MANAGER_NOVNC_PORT}..."

# 检查 noVNC 目录是否存在（Ubuntu 24.04 需要下载源码）
NOVNC_WEB_DIR="/usr/share/novnc"
if [ ! -d "$NOVNC_WEB_DIR" ]; then
    echo "ERROR: noVNC web directory not found at $NOVNC_WEB_DIR"
    echo "Please ensure Dockerfile includes noVNC source download step"
    exit 1
fi

# 使用 websockify 启动 noVNC
if command -v websockify &> /dev/null; then
    websockify --web="${NOVNC_WEB_DIR}" ${OPENCLAW_MANAGER_NOVNC_PORT} localhost:${OPENCLAW_MANAGER_VNC_PORT} &
else
    echo "ERROR: websockify command not found"
    exit 1
fi
sleep 2

# 检查 websockify 是否成功启动
if ! pgrep -f "websockify.*${OPENCLAW_MANAGER_NOVNC_PORT}" > /dev/null; then
    echo "ERROR: Failed to start websockify on port ${OPENCLAW_MANAGER_NOVNC_PORT}"
    exit 1
fi
echo "websockify started successfully"

# 启动 OpenClaw Manager 应用
echo "Starting OpenClaw Manager..."

# 设置 APPDIR 环境变量（AppRun 需要）
export APPDIR="$SQUASHFS_DIR"
# 在虚拟显示环境中启动应用
$SQUASHFS_DIR/AppRun --no-sandbox 2>&1 | tee ~/logs/openclaw-manager-app.log &
APP_PID=$!

sleep 3
echo "OpenClaw Manager started with PID $APP_PID!"
echo "Access via noVNC: http://localhost:${OPENCLAW_MANAGER_NOVNC_PORT}/vnc.html"

# 使用 trap 捕获退出信号
cleanup() {
    echo "Stopping OpenClaw Manager..."
    kill $APP_PID 2>/dev/null || true
    pkill -f "x11vnc.*${OPENCLAW_MANAGER_VNC_PORT}" 2>/dev/null || true
    pkill -f "websockify.*${OPENCLAW_MANAGER_NOVNC_PORT}" 2>/dev/null || true
    # 停止我们启动的 Xvfb 实例
    pkill -f "Xvfb :${DISPLAY_NUM}" 2>/dev/null || true
    exit 0
}
trap cleanup SIGTERM SIGINT SIGQUIT

# 保持脚本运行，监控应用进程
while kill -0 $APP_PID 2>/dev/null; do
    sleep 5
done

echo "OpenClaw Manager stopped"
exit 0