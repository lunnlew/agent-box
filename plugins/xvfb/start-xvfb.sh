#!/bin/bash
# Xvfb 基础服务启动脚本
# 仅启动 Xvfb 虚拟显示环境，不启动 x11vnc 和 noVNC

DISPLAY_NUM=99
SCREEN_SIZE="1920x1080x24"

# 清理旧进程
pkill -f "Xvfb :${DISPLAY_NUM}" 2>/dev/null || true
sleep 1

# 确保 X11 socket 目录存在
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix 2>/dev/null || true

# 启动虚拟帧缓冲
echo "Starting Xvfb on :${DISPLAY_NUM}..."

# 启动 Xvfb
Xvfb :${DISPLAY_NUM} -screen 0 ${SCREEN_SIZE} &
XVFB_PID=$!

sleep 2

# 检查是否启动成功
if ! pgrep -f "Xvfb :${DISPLAY_NUM}" > /dev/null; then
    echo "ERROR: Failed to start Xvfb"
    exit 1
fi

echo "Xvfb started with PID $XVFB_PID"

# 导出环境变量供其他应用使用（写入文件）
cat > /tmp/xvfb-env.sh << ENVEOF
export DISPLAY=:${DISPLAY_NUM}
export GDK_BACKEND=x11
export NO_AT_BRIDGE=1
ENVEOF

echo "Environment written to /tmp/xvfb-env.sh"

# 等待进程结束（保持脚本运行）
wait $XVFB_PID
