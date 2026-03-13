#!/bin/bash
# ===========================================
# AgentBox 容器入口脚本
# ===========================================
# 功能：
# 1. 初始化环境
# 2. 配置镜像源
# 3. 安装启用的插件
# 4. 启动主进程

set -e

# 引入共享函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib.sh" ]; then
    source "$SCRIPT_DIR/lib.sh"
else
    # 容器内路径
    source /opt/lib.sh 2>/dev/null || {
        echo "Error: lib.sh not found. Please ensure it's in the same directory as entrypoint.sh"
        exit 1
    }
fi

# ===========================================
# 初始化环境
# ===========================================
init_environment() {
    log_info "Initializing AgentBox environment..."

    mkdir -p "$HOME/tools" \
             "$HOME/plugins-data" \
             "$HOME/logs" \
             "$HOME/.npm" \
             "$HOME/.pip"

    touch "$HOME/.bashrc" "$HOME/.profile" 2>/dev/null || true

    log_success "Environment initialized"
}

# ===========================================
# 启动 Supervisor
# ===========================================
start_supervisord() {
    log_info "Starting Supervisor daemon..."

    if pgrep -x "supervisord" > /dev/null; then
        log_info "Supervisor already running"
        return 0
    fi

    mkdir -p "$HOME/supervisor" "$HOME/logs/supervisor" /tmp

    local supervisord_conf="$HOME/supervisor/supervisord.conf"

    cat > "$supervisord_conf" << 'EOF'
[unix_http_server]
file=/tmp/supervisor.sock
chmod=0700

[inet_http_server]
port=127.0.0.1:9001

[supervisord]
nodaemon=false
logfile=%(ENV_HOME)s/logs/supervisor/supervisord.log
pidfile=/tmp/supervisord.pid
childlogdir=%(ENV_HOME)s/logs/supervisor

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///tmp/supervisor.sock

[include]
files = %(ENV_HOME)s/supervisor/*.conf
EOF

    local supervisord_bin=$(command -v supervisord || echo "/usr/bin/supervisord")

    if [ ! -x "$supervisord_bin" ]; then
        log_error "supervisord not found at $supervisord_bin"
        return 1
    fi

    "$supervisord_bin" -c "$supervisord_conf" 2>&1 &

    sleep 2

    if pgrep -x "supervisord" > /dev/null; then
        log_success "Supervisor started successfully"
    else
        log_error "Failed to start Supervisor"
        if [ -f "$HOME/logs/supervisor/supervisord.log" ]; then
            log_info "Supervisor log (last 10 lines):"
            tail -10 "$HOME/logs/supervisor/supervisord.log" 2>/dev/null || true
        fi
    fi
}

# ===========================================
# 显示 Banner
# ===========================================
show_banner() {
    echo ""
    echo "==========================================="
    echo "   _____ _                   _    ____    "
    echo "  |  _  (_)                 | |  |  _ \\   "
    echo "  | |_) |_ _ __   __ _ _   _| | _| |_) |__"
    echo "  |  _ <| | '_ \\ / _\` | | | | |/ /  __/< "
    echo "  | |_) | | | | | (_| | |_| |   <| |    |"
    echo "  |____/|_|_| |_|\\__, |\\__,_|_|\\_\\_|    |"
    echo "                  __/ |                 "
    echo "                 |___/                  "
    echo "==========================================="
    echo ""
    echo "  AI Agent Integration Container"
    echo "  Version: 1.0.0"
    echo ""
    echo "  Commands:"
    echo "    agentbox list        - List installed plugins"
    echo "    agentbox install     - Install a plugin"
    echo "    agentbox uninstall   - Uninstall a plugin"
    echo "    agentbox status      - Show system status"
    echo "    agentbox mirrors     - Show mirror config"
    echo ""
}

# ===========================================
# Docker Socket 权限修复
# ===========================================
fix_docker_socket() {
    if [ -S /var/run/docker.sock ]; then
        chown root:docker /var/run/docker.sock 2>/dev/null || chmod 666 /var/run/docker.sock 2>/dev/null || true
        log_info "Docker socket permissions fixed"
    fi
}

# ===========================================
# 安装插件
# ===========================================
install_plugins() {
    log_info "Installing enabled plugins..."

    local plugins_config="$HOME/config/plugins.yaml"

    if [ ! -f "$plugins_config" ]; then
        log_warning "No plugins configuration found"
        return 0
    fi

    if command -v agentbox &> /dev/null; then
        agentbox install-all
    else
        log_warning "agentbox CLI not available, skipping plugin installation"
    fi
}

# ===========================================
# 主函数
# ===========================================

# Root 阶段
main_root() {
    show_banner
    init_environment

    fix_docker_socket

    if [ "$(id -u)" = "0" ]; then
        log_info "Switching to agent user..."
        exec gosu agent "$0" --agent "$@"
    fi
}

# Agent 阶段
main_agent() {
    configure_mirrors
    show_mirror_config
    check_dependencies

    start_supervisord

    if command -v agentbox &> /dev/null; then
        agentbox restore-links
    fi

    install_plugins

    if command -v agentbox &> /dev/null; then
        agentbox start-services
    fi

    log_success "AgentBox is ready!"

    if [ $# -gt 0 ]; then
        exec "$@"
    else
        if [ -t 0 ]; then
            exec bash
        else
            log_info "Running in background mode. Use 'docker exec -it agentbox bash' to enter."
            exec tail -f /dev/null
        fi
    fi
}

# 主入口
main() {
    if [ "$1" = "--agent" ]; then
        shift
        main_agent "$@"
    else
        main_root "$@"
    fi
}

main "$@"
