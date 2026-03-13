#!/bin/bash
# noVNC 基础服务停止脚本

DISPLAY_NUM=99
NOVNC_PORT=${NOVNC_PORT:-6080}

echo "Stopping noVNC services..."

pkill -f "websockify.*${NOVNC_PORT}" 2>/dev/null || true
pkill -f "x11vnc.*:${DISPLAY_NUM}" 2>/dev/null || true
pkill -f "Xvfb :${DISPLAY_NUM}" 2>/dev/null || true

rm -f /tmp/novnc-env.sh

echo "noVNC services stopped"