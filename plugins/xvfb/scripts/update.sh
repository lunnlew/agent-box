#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# Xvfb 更新脚本


log_info "Updating Xvfb..."

# 重新复制启动脚本
if [ -f /home/agent/plugins-config/xvfb/scripts/start.sh ]; then
  cp /home/agent/plugins-config/xvfb/scripts/start.sh ~/tools/xvfb-scripts/
  chmod +x ~/tools/xvfb-scripts/start.sh
fi

log_success "Xvfb updated successfully"