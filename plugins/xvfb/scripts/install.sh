#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# Xvfb 安装脚本


log_info "Installing Xvfb..."
rm -rf ~/tools/xvfb-scripts/* 2>/dev/null || true

# 复制启动脚本到可写目录
if [ -f /home/agent/plugins-config/xvfb/scripts/start.sh ]; then
  mkdir -p ~/tools/xvfb-scripts
  cp /home/agent/plugins-config/xvfb/scripts/start.sh ~/tools/xvfb-scripts/
  chmod +x ~/tools/xvfb-scripts/start.sh
fi

log_success "Xvfb installed successfully"