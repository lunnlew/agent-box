#!/bin/bash
# ===========================================
# AgentBox 容器入口脚本
# ===========================================
# 功能：
# 1. 初始化环境
# 2. 配置镜像源
# 3. 安装启用的插件
# 4. 启动主进程
#
# 容错设计：单个插件失败不会导致容器重启

# ⚠️ 不使用 set -e，避免单个命令失败导致脚本退出

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
        return 0
    else
        log_error "Failed to start Supervisor"
        if [ -f "$HOME/logs/supervisor/supervisord.log" ]; then
            log_info "Supervisor log (last 10 lines):"
            tail -10 "$HOME/logs/supervisor/supervisord.log" 2>/dev/null || true
        fi
        return 1
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
# 检查数据目录权限
# ===========================================
check_data_permissions() {
    # 检查关键目录是否可写
    local test_file="$HOME/.permission_test"

    if ! touch "$test_file" 2>/dev/null; then
        log_error "Permission denied: cannot write to $HOME"
        log_error ""
        log_error "Please fix permissions on the host:"
        log_error "  chmod -R 755 ./data"
        log_error "  chown -R 1000:1000 ./data"
        log_error ""
        log_error "Or remove ./data directory to let container create it:"
        log_error "  rm -rf ./data && mkdir -p ./data"
        return 1
    fi

    rm -f "$test_file" 2>/dev/null || true

    # 检查 .npm 目录
    if [ -d "$HOME/.npm" ]; then
        if [ ! -w "$HOME/.npm" ]; then
            log_warning ".npm directory permission issue detected"
            log_warning "Run on host: chown -R 1000:1000 ./data/.npm"
        fi
    fi

    return 0
}

# ===========================================
# 安装插件（容错模式）
# ===========================================
install_plugins() {
    log_info "Installing enabled plugins..."

    local plugins_config="$HOME/config/plugins.yaml"

    if [ ! -f "$plugins_config" ]; then
        log_warning "No plugins configuration found"
        return 0
    fi

    if command -v agentbox &> /dev/null; then
        # ⚠️ 使用 || true 确保即使安装失败也不退出
        agentbox install-all || {
            log_warning "Some plugins failed to install, continuing..."
        }
    else
        log_warning "agentbox CLI not available, skipping plugin installation"
    fi
}

# ===========================================
# 恢复插件链接（容错模式）
# ===========================================
restore_plugin_links() {
    log_info "Restoring plugin volume links..."

    if command -v agentbox &> /dev/null; then
        # ⚠️ 使用 || true 确保即使恢复失败也不退出
        agentbox restore-links || {
            log_warning "Failed to restore some plugin links, continuing..."
        }
    else
        log_warning "agentbox CLI not available, skipping link restoration"
    fi
}

# ===========================================
# 启动服务（容错模式）
# ===========================================
start_services() {
    log_info "Starting plugin services..."

    if command -v agentbox &> /dev/null; then
        # ⚠️ 使用 || true 确保即使启动失败也不退出
        agentbox start-all || {
            log_warning "Some plugin services failed to start, continuing..."
        }
    else
        log_warning "agentbox CLI not available, skipping service startup"
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
    # 检查数据目录权限
    check_data_permissions || log_warning "Permission check failed, some operations may fail"

    # 修复 Docker 配置目录权限（重要！）
    # 防止 root 阶段创建的文件导致 agent 用户权限问题
    mkdir -p ~/.docker
    chown agent:agent ~/.docker 2>/dev/null || true
    chmod 755 ~/.docker 2>/dev/null || true
    if [ ! -f ~/.docker/config.json ]; then
        echo '{}' > ~/.docker/config.json
    fi
    chown agent:agent ~/.docker/config.json 2>/dev/null || true
    chmod 644 ~/.docker/config.json 2>/dev/null || true

    # 配置镜像源（失败不影响后续）
    configure_mirrors || log_warning "Mirror configuration failed"
    show_mirror_config

    # 检查依赖（失败不影响后续）
    check_dependencies || log_warning "Dependency check failed"

    # 启动 Supervisor（关键步骤，失败需要报告）
    if ! start_supervisord; then
        log_error "Supervisor failed to start, services will not be managed"
    fi

    # 恢复插件链接（失败不影响后续）
    restore_plugin_links

    # 安装插件（失败不影响后续）
    install_plugins

    # 启动服务（失败不影响后续）
    start_services

    log_success "AgentBox is ready!"
    echo ""
    echo "==========================================="
    echo "  Note: Some plugins may have failed to"
    echo "        start. Check logs for details."
    echo "==========================================="
    echo ""

    # 执行传入的命令或进入 shell
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
