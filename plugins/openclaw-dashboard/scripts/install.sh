#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# OpenClaw Dashboard 安装脚本


log_info "Installing OpenClaw Dashboard..."

DASHBOARD_PATH="$HOME/tools/openclaw-dashboard"

# 清理旧目录
rm -rf "$DASHBOARD_PATH" 2>/dev/null || true
mkdir -p "$DASHBOARD_PATH"

# 克隆源码
log_info "Cloning OpenClaw Dashboard repository..."
git clone --depth 1 https://github.com/tugcantopaloglu/openclaw-dashboard.git "$DASHBOARD_PATH"

# 安装依赖
log_info "Installing dependencies..."
cd "$DASHBOARD_PATH"
npm install

log_success "OpenClaw Dashboard installed successfully"