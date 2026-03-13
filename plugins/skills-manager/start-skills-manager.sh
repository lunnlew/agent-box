#!/bin/bash
# Skills Manager 应用启动脚本
# 依赖 novnc-base 提供的虚拟显示环境

# 从 novnc-base 获取环境变量
if [ -f /tmp/novnc-env.sh ]; then
    source /tmp/novnc-env.sh
else
    echo "ERROR: novnc-base environment not found"
    echo "Please ensure novnc-base is running first"
    exit 1
fi

# 检查 DISPLAY 是否可用
if ! pgrep -f "Xvfb :${DISPLAY#:}" > /dev/null 2>&1; then
    echo "ERROR: Xvfb not running on $DISPLAY"
    echo "Please start novnc-base first"
    exit 1
fi

echo "Using virtual display: $DISPLAY"

# 设置 GTK/Tauri 必需的环境变量
export GDK_BACKEND=x11
export NO_AT_BRIDGE=1

# 确保 X server 允许本地连接
xhost +local: 2>/dev/null || true

# 检查 AppImage 是否已提取
SQUASHFS_DIR=""
if [ -d ~/tools/appimages/Skills-Manager/squashfs-root ]; then
    SQUASHFS_DIR=~/tools/appimages/Skills-Manager/squashfs-root
elif [ -d ~/tools/appimages/squashfs-root ]; then
    SQUASHFS_DIR=~/tools/appimages/squashfs-root
fi

if [ -z "$SQUASHFS_DIR" ]; then
    echo "ERROR: Extracted AppImage not found"
    echo "Please reinstall the plugin with: agentbox install skills-manager --force"
    exit 1
fi

# 启动 Skills Manager
echo "Starting Skills Manager..."
cd ~

# 在虚拟显示环境中启动应用
$SQUASHFS_DIR/AppRun --no-sandbox 2>&1 | tee ~/logs/skills-manager-app.log &
APP_PID=$!

sleep 3
echo "Skills Manager started with PID $APP_PID!"
echo "Access via noVNC: http://localhost:${NOVNC_PORT:-6080}/vnc.html"

# 保持脚本运行，监控应用进程
wait $APP_PID