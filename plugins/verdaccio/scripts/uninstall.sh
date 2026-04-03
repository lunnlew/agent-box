#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
    log_info() { echo "[INFO] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
    log_warning() { echo "[WARNING] $1"; }
}

log_info "Uninstalling Verdaccio..."

# 停止服务
pkill -f "verdaccio" 2>/dev/null || true

# 卸载 npm 包
npm uninstall -g verdaccio 2>/dev/null || true

# 保留配置和数据（用户可选择手动删除）
log_warning "Configuration and storage preserved at: $HOME/.verdaccio"
log_warning "To remove all data, run: rm -rf $HOME/.verdaccio"

log_success "Verdaccio uninstalled"