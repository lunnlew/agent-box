#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# OpenClaw Dashboard 卸载脚本


log_info "Uninstalling OpenClaw Dashboard..."

# 停止进程
pkill -f "openclaw-dashboard" 2>/dev/null || true
pkill -f "node.*server.js" 2>/dev/null || true

# 清理安装目录
rm -rf ~/tools/openclaw-dashboard 2>/dev/null || true

rm -rf ~/supervisor/openclaw-dashboard.conf 2>/dev/null || true
rm -rf ~/supervisor/openclaw-dashboard.sh 2>/dev/null || true

# ⚠️ 保留用户配置（OpenClaw 数据）
# rm -rf ~/.openclaw 2>/dev/null || true

log_success "OpenClaw Dashboard uninstalled"