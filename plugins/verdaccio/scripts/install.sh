#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
    log_info() { echo "[INFO] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
    log_warning() { echo "[WARNING] $1"; }
    log_error() { echo "[ERROR] $1"; }
}

VERDACCIO_PORT="${VERDACCIO_PORT:-4873}"
VERDACCIO_STORAGE="${VERDACCIO_STORAGE:-$HOME/.verdaccio/storage}"

log_info "Installing Verdaccio (Private NPM Registry)..."

# 创建目录结构
mkdir -p "$VERDACCIO_STORAGE"
mkdir -p "$HOME/.verdaccio"

# 安装 verdaccio
log_info "Installing verdaccio package..."
if type net_npm_install &>/dev/null; then
    net_npm_install verdaccio
else
    npm install -g verdaccio --registry "${NPM_REGISTRY:-https://registry.npmmirror.com}" --maxsockets 1
fi

# 检查安装
if ! command -v verdaccio &>/dev/null; then
    log_error "Verdaccio installation failed"
    exit 1
fi

log_success "Verdaccio installed: $(verdaccio --version 2>/dev/null || echo 'unknown')"

# 创建配置文件
CONFIG_FILE="$HOME/.verdaccio/config.yaml"
if [ ! -f "$CONFIG_FILE" ]; then
    log_info "Creating Verdaccio configuration..."

    cat > "$CONFIG_FILE" << 'EOF'
# Verdaccio Configuration for AgentBox
# 私有 NPM Registry 配置

storage: ~/.verdaccio/storage
plugins: ~/.verdaccio/plugins

web:
  title: AgentBox NPM Registry
  gravatar: true
  sort_packages: asc

auth:
  htpasswd:
    file: ~/.verdaccio/htpasswd
    max_users: 100

# 上游代理配置（支持离线缓存）
uplinks:
  npmjs:
    url: https://registry.npmmirror.com
    cache: true
    timeout: 60s
    maxage: 30d
  yarn:
    url: https://registry.yarnpkg.com
    cache: true

# 包访问权限
packages:
  '@*/*':
    access: $all
    publish: $authenticated
    unpublish: $authenticated
    proxy: npmjs

  '**':
    access: $all
    publish: $authenticated
    unpublish: $authenticated
    proxy: npmjs

# 日志配置
logs:
  - { type: stdout, format: pretty, level: warn }

# 服务器配置
server:
  keepAliveTimeout: 60

# 安全配置
security:
  api:
    jwt:
      sign:
        expiresIn: 60d
        notBefore: 1
  web:
    sign:
      expiresIn: 7d

# 中间件
middlewares:
  audit:
    enabled: true

# 速率限制
rateLimit:
  windowMs: 900000
  max: 1000
EOF

    log_success "Configuration created: $CONFIG_FILE"
fi

# 创建 htpasswd 文件（如果不存在）
HTPASSWD_FILE="$HOME/.verdaccio/htpasswd"
if [ ! -f "$HTPASSWD_FILE" ]; then
    touch "$HTPASSWD_FILE"
    log_info "Created empty htpasswd file"
fi

log_success "Verdaccio installation completed"
echo ""
echo "============================================"
echo "  Verdaccio 安装完成!"
echo "============================================"
echo ""
echo "配置:"
echo "  Registry URL: http://localhost:${VERDACCIO_PORT}"
echo "  Storage:      ${VERDACCIO_STORAGE}"
echo "  Config:       ${CONFIG_FILE}"
echo ""
echo "使用方法:"
echo "  1. 设置 npm registry: npm set registry http://localhost:${VERDACCIO_PORT}"
echo "  2. 或使用环境变量:    export NPM_REGISTRY=http://localhost:${VERDACCIO_PORT}"
echo "  3. 添加用户:          npm adduser --registry http://localhost:${VERDACCIO_PORT}"
echo ""
echo "============================================"