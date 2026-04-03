#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || true

VERDACCIO_PORT="${VERDACCIO_PORT:-4873}"
CONFIG_FILE="$HOME/.verdaccio/config.yaml"

# 检查配置文件
if [ ! -f "$CONFIG_FILE" ]; then
    log_warning "Verdaccio config not found, creating default..."
    mkdir -p "$HOME/.verdaccio"
    cat > "$CONFIG_FILE" << 'EOF'
storage: ~/.verdaccio/storage
plugins: ~/.verdaccio/plugins

web:
  title: AgentBox NPM Registry

auth:
  htpasswd:
    file: ~/.verdaccio/htpasswd

uplinks:
  npmjs:
    url: https://registry.npmmirror.com
    cache: true

packages:
  '@*/*':
    access: $all
    publish: $authenticated
    proxy: npmjs
  '**':
    access: $all
    publish: $authenticated
    proxy: npmjs

logs:
  - { type: stdout, format: pretty, level: warn }
EOF
fi

# 检查端口是否被占用
if lsof -i :$VERDACCIO_PORT >/dev/null 2>&1; then
    log_warning "Port $VERDACCIO_PORT is already in use"
    exit 0
fi

log_info "Starting Verdaccio on port $VERDACCIO_PORT..."

# 启动 verdaccio
exec verdaccio --config "$CONFIG_FILE" --listen $VERDACCIO_PORT