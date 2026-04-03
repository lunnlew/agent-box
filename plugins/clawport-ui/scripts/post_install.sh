#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# ClawPort UI 安装后配置


log_info "Initializing ClawPort UI..."

CLAWPORT_PORT="${CLAWPORT_PORT:-3000}"
WORKSPACE_PATH="${WORKSPACE_PATH:-$HOME/.openclaw/workspace}"
OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-}"

# 创建配置文件目录
mkdir -p ~/.config/clawport-ui

# 创建 .env.local 配置文件
log_info "Creating .env.local configuration..."
cat > ~/.config/clawport-ui/.env.local << EOF
WORKSPACE_PATH=${WORKSPACE_PATH}
OPENCLAW_BIN=$HOME/tools/bin/openclaw
OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN}
OPENCLAW_GATEWAY_PORT=${OPENCLAW_GATEWAY_PORT}
PORT=${CLAWPORT_PORT}
NEXT_PUBLIC_CLAWPORT_PORT=${CLAWPORT_PORT}
EOF

echo ""
echo "============================================"
echo "  ClawPort UI 安装完成!"
echo "============================================"
echo ""
echo "访问地址：http://localhost:${CLAWPORT_PORT}"
echo ""
echo "环境变量:"
echo "  WORKSPACE_PATH=~/.openclaw/workspace"
echo "  OPENCLAW_BIN=~/tools/bin/openclaw"
echo "  OPENCLAW_GATEWAY_PORT=18789"
echo ""
echo "启动服务:"
echo "  agentbox start clawport-ui"
echo ""
echo "或手动运行:"
echo "  clawport dev"
echo ""
echo "⚠️ 确保 OpenClaw Gateway 已启动并运行!"
echo "============================================"
echo ""