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
storage: storage
plugins: plugins

web:
  title: AgentBox NPM Registry

auth:
  htpasswd:
    file: htpasswd
    
uplinks:
  npmmirror:
    url: https://registry.npmmirror.com
    cache: true
    timeout: 60s
    maxage: 30d
  yarn:
    url: https://registry.yarnpkg.com
    cache: true
  cnpmjs:
    url: https://registry.npmjs.org
    cache: true
    timeout: 60s
    maxage: 30d
  npmjs:
    url: https://registry.npmjs.org
    cache: true
    timeout: 60s
    maxage: 30d

packages:
  '@*/*':
    access: $all
    publish: $authenticated
    proxy: npmmirror
  '**':
    access: $all
    publish: $authenticated
    proxy: npmmirror

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