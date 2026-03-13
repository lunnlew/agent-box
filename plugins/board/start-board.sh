#!/bin/bash
# AgentBox Dashboard 启动脚本
# 使用 Python HTTP 服务器提供静态页面和服务状态 API

set -e

# 配置
BOARD_DIR="$HOME/plugins-config/board"
PORT="${BOARD_PORT:-8888}"
LOG_FILE="$HOME/logs/board.log"

# 导出端口环境变量供 server.py 使用
export VSCODE_PORT_HOST="${VSCODE_PORT_HOST:-8686}"
export WEB_TERMINAL_PORT_HOST="${WEB_TERMINAL_PORT_HOST:-8687}"
export OPENCLAW_PORT_HOST="${OPENCLAW_PORT_HOST:-18789}"
export CAPAW_PORT_HOST="${CAPAW_PORT_HOST:-8688}"
export NOVNC_PORT_HOST="${NOVNC_PORT_HOST:-8690}"
export BOARD_PORT="$PORT"
export OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-}"

# 确保 Python 已安装
if ! command -v python3 &> /dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Python3 未安装" >> "$LOG_FILE"
    exit 1
fi

# 创建日志目录
mkdir -p ~/logs

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting AgentBox Dashboard on port $PORT" >> "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Service ports: VSCode=$VSCODE_PORT_HOST, Terminal=$WEB_TERMINAL_PORT_HOST, OpenClaw=$OPENCLAW_PORT_HOST, CoPaw=$CAPAW_PORT_HOST, noVNC=$NOVNC_PORT_HOST" >> "$LOG_FILE"

cd "$BOARD_DIR"

# 使用自定义 Python 服务器（支持 API）
exec python3 "$BOARD_DIR/server.py" 2>> "$LOG_FILE"