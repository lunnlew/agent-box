#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# OpenClaw Dashboard 更新脚本


log_info "Updating OpenClaw Dashboard..."

# 停止当前服务
pkill -f "openclaw-dashboard" 2>/dev/null || true
pkill -f "node.*server.js" 2>/dev/null || true

# Git pull 更新
cd ~/tools/openclaw-dashboard
git pull --rebase

# 重新安装依赖
npm install

# 验证
if [ ! -f ~/tools/openclaw-dashboard/package.json ]; then
  log_error "Update verification failed"
  exit 1
fi

log_success "OpenClaw Dashboard updated successfully"