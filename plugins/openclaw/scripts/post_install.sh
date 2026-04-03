#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# OpenClaw 安装后配置

OPENCLAW_PORT="${OPENCLAW_PORT:-18789}"

mkdir -p ~/.openclaw/devices
rm -rf ~/.openclaw/extensions/lossless-claw 2>/dev/null || true
if command -v openclaw &> /dev/null; then
  log_info "Installing lossless-claw plugin..."
  openclaw plugins install @martian-engineering/lossless-claw || true
fi

# 初始化配置（如果不存在）
if [ ! -f ~/.openclaw/openclaw.json ]; then
  log_info "Initializing OpenClaw configuration..."
  # 创建最小配置
  mkdir -p ~/.openclaw
  openclaw setup --no-interactive --mode local
  openclaw config set gateway.mode local
  openclaw config set auth.mode token
  openclaw config set auth.token "${OPENCLAW_GATEWAY_TOKEN}"
  log_success "Configuration created with gateway.mode=local"
fi

echo ""
echo "============================================"
echo "  OpenClaw 安装完成!"
echo "============================================"
echo ""
echo "快速开始:"
echo "  1. 设置 Token: export OPENCLAW_GATEWAY_TOKEN=your-token"
echo "  2. 启动 Gateway: openclaw gateway --port ${OPENCLAW_PORT}"
echo "  3. 访问 Dashboard: http://localhost:${OPENCLAW_PORT}"
echo ""
echo "或运行向导配置：openclaw onboard"
echo "============================================"
echo ""