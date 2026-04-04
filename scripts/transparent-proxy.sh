#!/bin/bash
# ===========================================
# AgentBox 透明代理配置脚本
# ===========================================
# 功能：使用 redsocks + iptables 自动拦截 TCP 流量
# 通过代理服务器转发，实现透明加速
#
# 用法：
#   source /opt/lib.sh
#   setup_transparent_proxy  # 启动透明代理
#   teardown_transparent_proxy  # 关闭透明代理
#
# 配置：
#   TRANSPARENT_PROXY_ENABLED - 是否启用（默认 false）
#   TRANSPARENT_PROXY_ADDR - 代理地址（默认 127.0.0.1:1080）
#   TRANSPARENT_PROXY_PORTS - 需要拦截的端口列表（默认 80,443）

# ===========================================
# 配置参数
# ===========================================
PROXY_ENABLED="${TRANSPARENT_PROXY_ENABLED:-false}"
PROXY_ADDR="${TRANSPARENT_PROXY_ADDR:-127.0.0.1:1080}"
PROXY_PORTS="${TRANSPARENT_PROXY_PORTS:-80,443}"
REDSOCKS_CONF="/etc/redsocks.conf"
REDSOCKS_PID="/var/run/redsocks.pid"

# 不拦截的网络段（白名单）
LOCAL_NETS=(
    "127.0.0.0/8"
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "169.254.0.0/16"
    "224.0.0.0/4"  # Multicast
    "240.0.0.0/4"  # Reserved
)

# 不拦截的端口
EXCLUDED_PORTS=(
    "4873"  # Verdaccio (本地 npm registry)
    "8080"  # 本地 pip server
    "9001"  # Supervisor
    "6080"  # noVNC
    "6081"  # noVNC Manager
    "7681"  # ttyd
    "8888"  # Dashboard
)

# ===========================================
# 生成 redsocks 配置文件
# ===========================================
generate_redsocks_config() {
    local proxy_ip=$(echo "$PROXY_ADDR" | cut -d: -f1)
    local proxy_port=$(echo "$PROXY_ADDR" | cut -d: -f2)

    cat > "$REDSOCKS_CONF" << EOF
base {
    log_debug = off;
    log_info = on;
    log = "stderr";
    daemon = on;
    redirector = iptables;
}

redsocks {
    local_ip = 127.0.0.1;
    local_port = 12301;
    ip = ${proxy_ip};
    port = ${proxy_port};
    type = socks5;
}

redsocks {
    local_ip = 127.0.0.1;
    local_port = 12302;
    ip = ${proxy_ip};
    port = ${proxy_port};
    type = http-connect;
}
EOF

    log_info "Generated redsocks config: $REDSOCKS_CONF"
}

# ===========================================
# 启动 redsocks
# ===========================================
start_redsocks() {
    if [ -f "$REDSOCKS_PID" ] && kill -0 $(cat "$REDSOCKS_PID") 2>/dev/null; then
        log_info "redsocks already running (PID: $(cat $REDSOCKS_PID))"
        return 0
    fi

    generate_redsocks_config

    # 启动 redsocks
    redsocks -c "$REDSOCKS_CONF" -p "$REDSOCKS_PID"

    sleep 1

    if [ -f "$REDSOCKS_PID" ] && kill -0 $(cat "$REDSOCKS_PID") 2>/dev/null; then
        log_success "redsocks started (PID: $(cat $REDSOCKS_PID))"
        return 0
    else
        log_error "Failed to start redsocks"
        return 1
    fi
}

# ===========================================
# 停止 redsocks
# ===========================================
stop_redsocks() {
    if [ -f "$REDSOCKS_PID" ]; then
        local pid=$(cat "$REDSOCKS_PID")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
            log_info "redsocks stopped (PID: $pid)"
        fi
        rm -f "$REDSOCKS_PID"
    fi
}

# ===========================================
# 配置 iptables 规则
# ===========================================
setup_iptables() {
    log_info "Setting up iptables rules for transparent proxy..."

    # 清理旧规则（如果存在）
    teardown_iptables

    # 创建新链
    iptables -t nat -N REDSOCKS 2>/dev/null || true

    # 添加白名单网络段（不拦截）
    for net in "${LOCAL_NETS[@]}"; do
        iptables -t nat -A REDSOCKS -d "$net" -j RETURN
    done

    # 添加白名单端口（不拦截）
    for port in "${EXCLUDED_PORTS[@]}"; do
        iptables -t nat -A REDSOCKS -p tcp --dport "$port" -j RETURN
    done

    # 重定向 HTTP (80) 到 redsocks socks5 端口
    if echo "$PROXY_PORTS" | grep -q "80"; then
        iptables -t nat -A REDSOCKS -p tcp --dport 80 -j REDIRECT --to-port 12301
    fi

    # 重定向 HTTPS (443) 到 redsocks http-connect 端口
    if echo "$PROXY_PORTS" | grep -q "443"; then
        iptables -t nat -A REDSOCKS -p tcp --dport 443 -j REDIRECT --to-port 12302
    fi

    # 应用规则到所有出站流量
    iptables -t nat -A OUTPUT -p tcp -j REDSOCKS

    log_success "iptables rules configured"
}

# ===========================================
# 清理 iptables 规则
# ===========================================
teardown_iptables() {
    log_info "Removing iptables rules for transparent proxy..."

    # 删除 OUTPUT 链中的 REDSOCKS 引用
    iptables -t nat -D OUTPUT -p tcp -j REDSOCKS 2>/dev/null || true

    # 清空并删除 REDSOCKS 链
    iptables -t nat -F REDSOCKS 2>/dev/null || true
    iptables -t nat -X REDSOCKS 2>/dev/null || true

    log_success "iptables rules removed"
}

# ===========================================
# 启动透明代理
# ===========================================
setup_transparent_proxy() {
    if [ "$PROXY_ENABLED" != "true" ]; then
        log_info "Transparent proxy disabled (TRANSPARENT_PROXY_ENABLED=$PROXY_ENABLED)"
        return 0
    fi

    # 检查是否有代理地址
    if [ -z "$PROXY_ADDR" ]; then
        log_warning "No proxy address configured (TRANSPARENT_PROXY_ADDR)"
        return 1
    fi

    # 检查 iptables 权限
    if ! iptables -L -t nat >/dev/null 2>&1; then
        log_warning "No iptables permission (need NET_ADMIN capability)"
        return 1
    fi

    log_info "Starting transparent proxy..."
    log_info "Proxy: $PROXY_ADDR, Ports: $PROXY_PORTS"

    start_redsocks
    setup_iptables

    log_success "Transparent proxy active"
}

# ===========================================
# 关闭透明代理
# ===========================================
teardown_transparent_proxy() {
    log_info "Stopping transparent proxy..."

    teardown_iptables
    stop_redsocks

    log_success "Transparent proxy stopped"
}

# ===========================================
# 显示透明代理状态
# ===========================================
show_transparent_proxy_status() {
    echo -e "\n${CYAN}Transparent Proxy Status:${NC}"

    if [ "$PROXY_ENABLED" != "true" ]; then
        echo "  Status: Disabled"
        return 0
    fi

    echo "  Status: Enabled"
    echo "  Proxy: $PROXY_ADDR"
    echo "  Intercepted Ports: $PROXY_PORTS"

    # 检查 redsocks 状态
    if [ -f "$REDSOCKS_PID" ] && kill -0 $(cat "$REDSOCKS_PID") 2>/dev/null; then
        echo "  Redsocks: Running (PID: $(cat $REDSOCKS_PID))"
    else
        echo "  Redsocks: Not running"
    fi

    # 显示 iptables 规则
    echo "  iptables rules:"
    iptables -t nat -L REDSOCKS -n 2>/dev/null | head -10 || echo "    (no rules)"
}