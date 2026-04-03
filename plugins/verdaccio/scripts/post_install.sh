#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
    log_info() { echo "[INFO] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
}

VERDACCIO_PORT="${VERDACCIO_PORT:-4873}"

# 创建存储目录
mkdir -p "$HOME/.verdaccio/storage"
mkdir -p "$HOME/.verdaccio/plugins"

# 设置权限
chmod -R 755 "$HOME/.verdaccio"

# 提示用户配置 npm registry
log_info "Post-install: Verdaccio configuration"

# 写入环境变量到 .bashrc
BASHRC="$HOME/.bashrc"
if ! grep -q "VERDACCIO_PORT" "$BASHRC" 2>/dev/null; then
    echo "" >> "$BASHRC"
    echo "# AgentBox: Verdaccio local npm registry" >> "$BASHRC"
    echo "export VERDACCIO_PORT=${VERDACCIO_PORT}" >> "$BASHRC"
    log_info "Added VERDACCIO_PORT to .bashrc"
fi

log_success "Post-install completed"