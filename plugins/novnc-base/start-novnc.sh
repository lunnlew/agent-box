#!/bin/bash
# noVNC 基础服务启动脚本
# 启动 Xvfb + x11vnc + noVNC，为 GUI 应用提供虚拟显示

DISPLAY_NUM=99
VNC_PORT=5900
NOVNC_PORT=${NOVNC_PORT:-6080}
SCREEN_SIZE="1920x1080x24"

# 如果已经运行，等待并监控现有进程
if pgrep -f "Xvfb :${DISPLAY_NUM}" > /dev/null 2>&1; then
    echo "noVNC already running on display :${DISPLAY_NUM}"
    echo "Access via: http://localhost:${NOVNC_PORT}/vnc.html?autoconnect=true&reconnect=true&resize=scale"
    # 监控现有进程
    XVFB_PID=$(pgrep -f "Xvfb :${DISPLAY_NUM}" | head -1)
    if [ -n "$XVFB_PID" ]; then
        # 导出环境变量供其他应用使用
        cat > /tmp/novnc-env.sh << ENVEOF
export DISPLAY=:${DISPLAY_NUM}
export WEBKIT_DISABLE_COMPOSITING_MODE=1
export NOVNC_PORT=${NOVNC_PORT}
export VNC_PORT=${VNC_PORT}
export GDK_BACKEND=x11
export NO_AT_BRIDGE=1
ENVEOF
        # 等待进程结束
        while kill -0 $XVFB_PID 2>/dev/null; do
            sleep 5
        done
    fi
    exit 0
fi

# 清理旧进程
pkill -f "Xvfb :${DISPLAY_NUM}" 2>/dev/null || true
pkill -f "x11vnc.*:${DISPLAY_NUM}" 2>/dev/null || true
pkill -f "websockify.*${NOVNC_PORT}" 2>/dev/null || true
sleep 1

# 确保 X11 socket 目录存在
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix 2>/dev/null || true

# 启动虚拟帧缓冲
echo "Starting Xvfb on :${DISPLAY_NUM}..."
Xvfb :${DISPLAY_NUM} -screen 0 ${SCREEN_SIZE} &
XVFB_PID=$!
sleep 2

# 设置 DISPLAY 环境变量
export DISPLAY=:${DISPLAY_NUM}

# 允许本地客户端连接 X server（GTK 应用需要）
xhost +local: 2>/dev/null || true

# 启动 VNC 服务器
echo "Starting x11vnc on port ${VNC_PORT}..."
x11vnc -display :${DISPLAY_NUM} -forever -shared -rfbport ${VNC_PORT} -nopw -bg
sleep 1

# 启动 noVNC
echo "Starting noVNC on port ${NOVNC_PORT}..."
if command -v websockify &> /dev/null; then
    websockify --web=/usr/share/novnc/ ${NOVNC_PORT} localhost:${VNC_PORT} &
elif [ -f /usr/share/novnc/websockify/websockify.py ]; then
    python3 /usr/share/novnc/websockify/websockify.py --web=/usr/share/novnc/ ${NOVNC_PORT} localhost:${VNC_PORT} &
else
    echo "ERROR: websockify not found"
    exit 1
fi
sleep 2

echo "noVNC base service started successfully!"
echo "Virtual display: :${DISPLAY_NUM}"
echo "VNC port: ${VNC_PORT}"
echo "Access via: http://localhost:${NOVNC_PORT}/vnc.html?autoconnect=true&reconnect=true&resize=scale"

# 导出环境变量供其他应用使用
cat > /tmp/novnc-env.sh << ENVEOF
export DISPLAY=:${DISPLAY_NUM}
export WEBKIT_DISABLE_COMPOSITING_MODE=1
export NOVNC_PORT=${NOVNC_PORT}
export VNC_PORT=${VNC_PORT}
export GDK_BACKEND=x11
export NO_AT_BRIDGE=1
ENVEOF

# 保持脚本运行，监控 Xvfb 进程
wait $XVFB_PID