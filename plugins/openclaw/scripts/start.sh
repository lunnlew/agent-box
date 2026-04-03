#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# OpenClaw Gateway 启动脚本

OPENCLAW_PORT="${OPENCLAW_PORT:-18789}"

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

openclaw gateway --port ${OPENCLAW_PORT} --bind lan