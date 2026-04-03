#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
}

log_info "Uninstalling Docker CLI..."

# 移除二进制文件
rm -f $HOME/tools/bin/docker 2>/dev/null || true

# 移除相关组件
rm -f $HOME/tools/bin/docker-compose 2>/dev/null || true
rm -f $HOME/tools/bin/ctr 2>/dev/null || true
rm -f $HOME/tools/bin/containerd 2>/dev/null || true

log_success "Docker CLI uninstalled"