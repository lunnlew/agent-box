#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
    log_info() { echo "[INFO] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
    log_warning() { echo "[WARNING] $1"; }
}

log_info "Updating Verdaccio..."

# 更新 npm 包
if type net_npm_install &>/dev/null; then
    net_npm_install verdaccio@latest
else
    npm update -g verdaccio --registry "${NPM_REGISTRY:-https://registry.npmmirror.com}"
fi

log_success "Verdaccio updated: $(verdaccio --version 2>/dev/null || echo 'unknown')"