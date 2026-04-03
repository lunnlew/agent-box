#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || true

VERDACCIO_PORT="${VERDACCIO_PORT:-4873}"

log_info "Stopping Verdaccio..."

# 查找并停止 verdaccio 进程
pkill -f "verdaccio" 2>/dev/null || true

# 等待进程结束
sleep 2

# 检查是否停止
if lsof -i :$VERDACCIO_PORT >/dev/null 2>&1; then
    log_warning "Port $VERDACCIO_PORT still in use, force killing..."
    fuser -k $VERDACCIO_PORT/tcp 2>/dev/null || true
fi

log_success "Verdaccio stopped"