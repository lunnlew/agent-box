#!/bin/bash
# ===========================================
# AgentBox 插件管理 CLI
# ===========================================
# 用法：agentbox {install|uninstall|list|enable|disable|update|status|mirrors|install-all} [plugin-name]

set -e

# 引入共享函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib.sh" ]; then
    source "$SCRIPT_DIR/lib.sh"
else
    # 容器内路径
    source /opt/lib.sh 2>/dev/null || {
        echo "Error: lib.sh not found. Please ensure it's in the same directory as plugin-manager.sh"
        exit 1
    }
fi

# ===========================================
# 配置路径
# ===========================================
PLUGINS_CONFIG="$HOME/config/plugins.yaml"
PLUGINS_DEF_DIR="$HOME/plugins-config"          # 插件定义目录（只读）
PLUGINS_DATA_DIR="$HOME/plugins-data"           # 插件数据目录（可读写）
TOOLS_DIR="$HOME/tools"
CACHE_DIR="$HOME/cache"
SUPERVISOR_CONF="$HOME/supervisor/supervisord.conf"

# ===========================================
# 帮助信息
# ===========================================
show_help() {
    cat << EOF
AgentBox Plugin Manager v1.0.0

用法：agentbox <command> [options]

命令:
  install <name> [--force]  安装指定插件 (--force 强制重装)
  uninstall <name>          卸载指定插件
  update <name>             更新指定插件
  list                      列出所有可用插件
  status                    显示系统状态
  mirrors                   显示镜像源配置
  set-mirror <type> <url>   设置镜像源
  enable <name>             在配置中启用插件
  disable <name>            在配置中禁用插件
  install-all [--force]     安装所有已启用的插件 (--force 强制重装)
  restore-links             恢复所有已安装插件的符号链接
  help                      显示此帮助信息

服务管理:
  start-service <name>      启动指定插件服务
  stop-service <name>       停止指定插件服务
  restart-service <name>    重启指定插件服务
  service-status <name>     查看指定插件服务状态
  start-services            启动所有已启用插件的服务

镜像源类型 (set-mirror):
  npm      NPM 镜像源
  pnpm     PNPM 镜像源
  pip      PIP 镜像源
  go       Go 模块代理
  github   GitHub 代理

示例:
  agentbox install claude-code
  agentbox install claude-code --force
  agentbox install-all
  agentbox list
  agentbox status
  agentbox start-service openclaw
  agentbox service-status openclaw
  agentbox restart-service vscode-server
  agentbox mirrors
  agentbox set-mirror npm https://registry.npmmirror.com

EOF
}

# ===========================================
# YAML 解析辅助函数
# ===========================================

# 解析插件 YAML 定义（简单字段）
# 用法：parse_plugin_yaml <file> <field>
parse_plugin_yaml() {
    local plugin_file="$1"
    local field="$2"

    if [ ! -f "$plugin_file" ]; then
        return 1
    fi

    grep "^${field}:" "$plugin_file" | head -1 | sed 's/^[^:]*: *//' | tr -d '"'
}

# 获取插件安装命令
# 使用共享库中的 get_yaml_list_commands 函数
get_install_commands() {
    local plugin_file="$1"
    get_yaml_list_commands "$plugin_file" "install"
}

# ===========================================
# 插件卷管理
# ===========================================

# 解析 volumes 定义
parse_volumes() {
    local plugin_file="$1"

    if [ ! -f "$plugin_file" ]; then
        return 0
    fi

    awk '/^volumes:/ {in_volumes=1; next} /^[a-zA-Z_]+:/ {in_volumes=0} in_volumes && /^\s+-/ {print}' "$plugin_file" | sed 's/^\s*- //' | while read -r line; do
        echo "$line" | cut -d':' -f1 | xargs
    done
}

# 确保插件 volumes 符号链接存在 (容器重启后调用)
ensure_plugin_volumes() {
    local plugin_name="$1"
    local plugin_file="$2"

    local volumes=$(parse_volumes "$plugin_file")

    if [ -z "$volumes" ]; then
        return 0
    fi

    log_info "Ensuring volume links for $plugin_name..."

    local plugin_data_root="$PLUGINS_DATA_DIR/$plugin_name"

    while IFS= read -r volume; do
        if [ -z "$volume" ]; then
            continue
        fi

        local vol_path="${volume/#\~/$HOME}"
        local vol_name=$(basename "$vol_path")
        local isolated_path="$plugin_data_root/$vol_name"

        # 情况 1: 符号链接已存在且正确
        if [ -L "$vol_path" ]; then
            local link_target=$(readlink -f "$vol_path" 2>/dev/null || readlink "$vol_path")
            if [ "$link_target" = "$isolated_path" ]; then
                log_info "  Link OK: $vol_path -> $isolated_path"
                continue
            else
                log_warning "  Link points to wrong target: $vol_path -> $link_target"
                rm -f "$vol_path"
            fi
        fi

        # 情况 2: 隔离数据存在，需要重建链接
        if [ -e "$isolated_path" ]; then
            local is_file=false
            [ -f "$isolated_path" ] && is_file=true

            if [ -e "$vol_path" ] && [ ! -L "$vol_path" ]; then
                log_info "  Path exists but not a symlink: $vol_path"
                if [ "$is_file" = true ]; then
                    if [ "$vol_path" -nt "$isolated_path" ]; then
                        cp -a "$vol_path" "$isolated_path"
                    fi
                else
                    cp -a "$vol_path"/. "$isolated_path/" 2>/dev/null || true
                fi
                rm -rf "$vol_path"
            fi

            ln -sf "$isolated_path" "$vol_path"
            log_info "  Restored link: $vol_path -> $isolated_path"
        else
            log_warning "  Isolated data not found: $isolated_path"
            log_warning "  Plugin $plugin_name may need reinstallation"
        fi
    done <<< "$volumes"
}

# 标记插件已安装
mark_plugin_installed() {
    local plugin_name="$1"
    local plugin_data_dir="$PLUGINS_DATA_DIR/$plugin_name"
    local install_marker="$plugin_data_dir/.installed"

    mkdir -p "$plugin_data_dir"

    echo "installed_at=$(date -Iseconds)" > "$install_marker"
    echo "plugin_name=$plugin_name" >> "$install_marker"
}

# 设置插件数据目录隔离 (安装完成后调用)
setup_plugin_volumes() {
    local plugin_name="$1"
    local plugin_file="$2"

    local volumes=$(parse_volumes "$plugin_file")

    if [ -z "$volumes" ]; then
        return 0
    fi

    log_info "Setting up isolated volumes for $plugin_name..."

    local plugin_data_root="$PLUGINS_DATA_DIR/$plugin_name"
    mkdir -p "$plugin_data_root"

    while IFS= read -r volume; do
        if [ -z "$volume" ]; then
            continue
        fi

        local vol_path="${volume/#\~/$HOME}"
        local vol_name=$(basename "$vol_path")
        local isolated_path="$plugin_data_root/$vol_name"

        # 智能判断文件还是目录
        local is_file=false
        if [ -e "$vol_path" ]; then
            [ -f "$vol_path" ] && is_file=true
        elif [ -e "$isolated_path" ]; then
            [ -f "$isolated_path" ] && is_file=true
        else
            local dir_names="local config cache data lib bin share .claude .config .cache .opencode .qwen-code .code-server"
            if echo " $dir_names " | grep -q " $vol_name "; then
                is_file=false
            elif [[ "$vol_name" == .* ]]; then
                is_file=false
            elif [[ "$vol_name" == *.* ]]; then
                is_file=true
            fi
        fi

        if [ "$is_file" = true ]; then
            if [ -f "$vol_path" ] && [ ! -L "$vol_path" ]; then
                mv "$vol_path" "$isolated_path" 2>/dev/null || true
            fi
            [ ! -f "$isolated_path" ] && touch "$isolated_path"
            if [ ! -L "$vol_path" ]; then
                rm -f "$vol_path" 2>/dev/null || true
                ln -sf "$isolated_path" "$vol_path"
                log_info "  Linked file: $vol_path -> $isolated_path"
            fi
        else
            mkdir -p "$isolated_path"
            if [ -e "$vol_path" ] && [ ! -L "$vol_path" ]; then
                if [ -d "$vol_path" ]; then
                    cp -a "$vol_path"/. "$isolated_path/" 2>/dev/null || true
                else
                    cp -a "$vol_path" "$isolated_path" 2>/dev/null || true
                fi
                rm -rf "$vol_path"
            fi
            if [ ! -L "$vol_path" ]; then
                ln -sf "$isolated_path" "$vol_path"
                log_info "  Linked dir: $vol_path -> $isolated_path"
            fi
        fi
    done <<< "$volumes"
}

# ===========================================
# 插件安装管理
# ===========================================

# 执行安装命令（带错误处理和重试）
execute_install_commands() {
    local plugin_file="$1"
    local plugin_name="$2"

    local commands=$(get_install_commands "$plugin_file")

    if [ -z "$commands" ]; then
        log_warning "No install commands found for $plugin_name"
        return 0
    fi

    while IFS= read -r cmd; do
        if [ -n "$cmd" ] && [[ ! "$cmd" =~ ^[|\-]$ ]]; then
            log_info "Executing: $cmd"

            local output
            local exit_code
            output=$(eval "$cmd" 2>&1) && exit_code=0 || exit_code=$?

            if [ $exit_code -ne 0 ]; then
                if echo "$output" | grep -q "ENOTEMPTY"; then
                    log_warning "Detected npm ENOTEMPTY error, attempting cleanup and retry..."

                    if [[ "$cmd" =~ npm\ install\ -g\ ([^[:space:]]+) ]]; then
                        local pkg_name="${BASH_REMATCH[1]}"
                        log_info "Cleaning up existing npm package: $pkg_name"
                        npm uninstall -g "$pkg_name" 2>/dev/null || true
                        rm -rf "$HOME/tools/lib/node_modules/$pkg_name" 2>/dev/null || true

                        log_info "Retrying: $cmd"
                        eval "$cmd"
                    else
                        log_error "Install command failed: $output"
                        return 1
                    fi
                else
                    log_error "Install command failed: $output"
                    return 1
                fi
            fi
        fi
    done <<< "$commands"

    return 0
}

# 检查插件是否已安装
is_plugin_installed() {
    local plugin_name="$1"
    local plugin_file="$2"

    local install_marker="$PLUGINS_DATA_DIR/$plugin_name/.installed"
    if [ -f "$install_marker" ]; then
        log_info "Plugin $plugin_name marked as installed, verifying..."

        ensure_plugin_volumes "$plugin_name" "$plugin_file"
        process_plugin_env "$plugin_file" "setup"

        local health_cmd=$(get_yaml_field_multiline "$plugin_file" "healthcheck" "command")
        if [ -n "$health_cmd" ]; then
            local first_line=$(echo "$health_cmd" | head -1)
            local cmd_name=$(echo "$first_line" | awk '{print $1}')

            if ! command -v "$cmd_name" &>/dev/null; then
                log_warning "Command '$cmd_name' not found in PATH for $plugin_name"
                log_warning "Current PATH: $PATH"
                return 1
            fi

            if eval "$health_cmd" &>/dev/null; then
                log_info "Healthcheck passed for $plugin_name"
                return 0
            else
                log_warning "Plugin $plugin_name healthcheck failed, will reinstall..."
                return 1
            fi
        fi
        return 0
    fi

    return 1
}

# 安装单个插件
install_plugin() {
    local plugin_name="$1"
    local plugin_file="$PLUGINS_DEF_DIR/$plugin_name/plugin.yaml"
    local force_install="${2:-false}"

    log_info "Installing plugin: $plugin_name"

    if [ ! -f "$plugin_file" ]; then
        log_error "Plugin definition not found: $plugin_file"
        return 1
    fi

    # 检查并安装插件依赖
    local plugin_deps=$(sed -n '/^depends:/,/^[a-z]/p' "$plugin_file" | grep -E '^\s+-' | sed 's/^\s*- //')
    if [ -n "$plugin_deps" ]; then
        log_info "Checking plugin dependencies..."
        while IFS= read -r dep_name; do
            if [ -n "$dep_name" ]; then
                local dep_file="$PLUGINS_DEF_DIR/$dep_name/plugin.yaml"
                if [ ! -f "$dep_file" ]; then
                    log_error "Dependency plugin not found: $dep_name"
                    return 1
                fi
                if ! is_plugin_installed "$dep_name" "$dep_file"; then
                    log_info "Installing dependency: $dep_name"
                    if ! install_plugin "$dep_name" "$force_install"; then
                        log_error "Failed to install dependency: $dep_name"
                        return 1
                    fi
                else
                    log_info "Dependency already installed: $dep_name"
                fi
            fi
        done <<< "$plugin_deps"
    fi

    if [ "$force_install" != "true" ] && is_plugin_installed "$plugin_name" "$plugin_file"; then
        log_success "Plugin already installed: $plugin_name (skip)"
        return 0
    fi

    if ! check_plugin_dependencies "$plugin_file"; then
        log_error "Dependency check failed for $plugin_name"
        return 1
    fi

    log_info "Processing environment variables..."
    if ! process_plugin_env "$plugin_file" "all"; then
        log_error "Environment check failed for $plugin_name"
        return 1
    fi

    if ! execute_install_commands "$plugin_file" "$plugin_name"; then
        log_error "Installation failed for $plugin_name"
        return 1
    fi

    setup_plugin_volumes "$plugin_name" "$plugin_file"

    local post_install=$(get_yaml_list_commands "$plugin_file" "post_install")
    if [ -n "$post_install" ]; then
        log_info "Running post-install commands..."
        while IFS= read -r cmd; do
            if [ -n "$cmd" ] && [[ ! "$cmd" =~ ^[[:space:]]*# ]]; then
                log_info "  $(echo "$cmd" | head -1)"
                eval "$cmd"
            fi
        done <<< "$post_install"
    fi

    mark_plugin_installed "$plugin_name"
    log_success "Plugin installed: $plugin_name"
}

# 卸载插件
uninstall_plugin() {
    local plugin_name="$1"
    local plugin_file="$PLUGINS_DEF_DIR/$plugin_name/plugin.yaml"

    log_info "Uninstalling plugin: $plugin_name"

    if [ ! -f "$plugin_file" ]; then
        log_warning "Plugin definition not found: $plugin_name"
        return 0
    fi

    local commands=$(get_yaml_list_commands "$plugin_file" "uninstall")
    if [ -n "$commands" ]; then
        while IFS= read -r cmd; do
            if [ -n "$cmd" ]; then
                log_info "Executing: $(echo "$cmd" | head -1)"
                eval "$cmd"
            fi
        done <<< "$commands"
    fi

    log_success "Plugin uninstalled: $plugin_name"
}

# 更新插件
update_plugin() {
    local plugin_name="$1"
    local plugin_file="$PLUGINS_DEF_DIR/$plugin_name/plugin.yaml"

    log_info "Updating plugin: $plugin_name"

    if [ ! -f "$plugin_file" ]; then
        log_error "Plugin definition not found: $plugin_name"
        return 1
    fi

    local commands=$(get_yaml_list_commands "$plugin_file" "update")
    if [ -z "$commands" ]; then
        log_warning "No update commands found, trying reinstall..."
        uninstall_plugin "$plugin_name"
        install_plugin "$plugin_name"
        return $?
    fi

    while IFS= read -r cmd; do
        if [ -n "$cmd" ]; then
            log_info "Executing: $(echo "$cmd" | head -1)"
            eval "$cmd"
        fi
    done <<< "$commands"

    log_success "Plugin updated: $plugin_name"
}

# ===========================================
# 插件列表和状态
# ===========================================

# 列出所有插件
list_plugins() {
    echo -e "\n${CYAN}Available Plugins:${NC}"
    echo "==================="
    echo ""

    for plugin_dir in "$PLUGINS_DEF_DIR"/*/; do
        if [ -d "$plugin_dir" ]; then
            local plugin_name=$(basename "$plugin_dir")
            local plugin_file="$plugin_dir/plugin.yaml"

            if [ -f "$plugin_file" ]; then
                local desc=$(parse_plugin_yaml "$plugin_file" "description")
                local version=$(parse_plugin_yaml "$plugin_file" "version")
                local status=""

                if grep -q "name: $plugin_name" "$PLUGINS_CONFIG" 2>/dev/null; then
                    if grep -A5 "name: $plugin_name" "$PLUGINS_CONFIG" | grep -q "enabled: true"; then
                        status="${GREEN}[ENABLED]${NC}"
                    else
                        status="${YELLOW}[DISABLED]${NC}"
                    fi
                else
                    status="${RED}[NOT IN CONFIG]${NC}"
                fi

                echo -e "  ${BLUE}$plugin_name${NC} ($version)"
                echo "    $desc"
                echo -e "    Status: $status"
                echo ""
            fi
        fi
    done
}

# 显示系统状态
show_status() {
    echo -e "\n${CYAN}AgentBox System Status${NC}"
    echo "========================"
    echo ""

    echo "Environment:"
    echo "  Node.js: $(node --version 2>/dev/null || echo 'Not installed')"
    echo "  npm: $(npm --version 2>/dev/null || echo 'Not installed')"
    echo "  pnpm: $(pnpm --version 2>/dev/null || echo 'Not installed')"
    echo "  Python: $(python3 --version 2>/dev/null || echo 'Not installed')"
    echo "  pip: $(pip3 --version 2>/dev/null || echo 'Not installed')"
    echo ""

    echo "Directories:"
    echo "  Data: $HOME/data"
    echo "  Tools: $HOME/tools"
    echo "  Workspace: $HOME/workspace"
    echo "  Cache: $HOME/cache"
    echo "  Config: $HOME/config"
    echo ""

    echo "Installed Tools:"
    ls -la "$TOOLS_DIR/bin" 2>/dev/null || echo "  (empty)"
    echo ""

    echo "Environment Variables:"
    env | grep -E '(API_KEY|TOKEN)' | sed 's/=.*/=***/' || echo "  (none set)"
}

# 显示镜像源配置（使用共享库中的 show_mirror_config）
show_mirrors() {
    echo -e "\n${CYAN}Mirror Sources Configuration${NC}"
    echo "=============================="
    show_mirror_config
    echo -e "\n${YELLOW}Tips:${NC}"
    echo "  Use 'agentbox set-mirror <type> <url>' to change mirror source"
    echo "  Example: agentbox set-mirror npm https://registry.npmmirror.com"
    echo "  For proxy, set environment variables: HTTP_PROXY, HTTPS_PROXY, INSTALL_PROXY"
    echo ""
}

# 设置镜像源
set_mirror() {
    local mirror_type="$1"
    local mirror_url="$2"

    if [ -z "$mirror_type" ] || [ -z "$mirror_url" ]; then
        log_error "Usage: agentbox set-mirror <type> <url>"
        echo "  Types: npm, pnpm, pip, go, github"
        return 1
    fi

    case "$mirror_type" in
        npm)
            npm config set registry "$mirror_url" -g 2>/dev/null || true
            log_success "NPM registry set to: $mirror_url"
            ;;
        pnpm)
            if check_command pnpm; then
                pnpm config set registry "$mirror_url" -g 2>/dev/null || true
                log_success "PNPM registry set to: $mirror_url"
            else
                log_error "pnpm is not installed"
            fi
            ;;
        pip)
            pip3 config set global.index-url "$mirror_url" 2>/dev/null || true
            log_success "PIP index-url set to: $mirror_url"
            local host=$(echo "$mirror_url" | sed 's|https\?://||' | cut -d'/' -f1)
            pip3 config set global.trusted-host "$host" 2>/dev/null || true
            ;;
        go)
            export GOPROXY="$mirror_url"
            go env -w GOPROXY="$mirror_url" 2>/dev/null || true
            log_success "GOPROXY set to: $mirror_url"
            ;;
        github)
            export GITHUB_PROXY="$mirror_url"
            log_success "GITHUB_PROXY set to: $mirror_url"
            echo "  Note: This only affects scripts that use \$GITHUB_PROXY variable"
            ;;
        *)
            log_error "Unknown mirror type: $mirror_type"
            echo "  Supported types: npm, pnpm, pip, go, github"
            return 1
            ;;
    esac
}

# ===========================================
# 批量操作
# ===========================================

# 安装所有已启用的插件
install_all_plugins() {
    local force_install="${1:-false}"
    log_info "Installing all enabled plugins..."

    if [ ! -f "$PLUGINS_CONFIG" ]; then
        log_warning "Plugin config not found: $PLUGINS_CONFIG"
        return 0
    fi

    local enabled_plugins=$(grep -B1 'enabled: true' "$PLUGINS_CONFIG" | grep 'name:' | sed 's/.*name:[[:space:]]*//' | tr -d ' ')

    if [ -z "$enabled_plugins" ]; then
        log_warning "No enabled plugins found in config"
        return 0
    fi

    log_info "Found enabled plugins: $(echo $enabled_plugins | tr '\n' ' ')"

    while IFS= read -r plugin_name; do
        if [ -n "$plugin_name" ]; then
            install_plugin "$plugin_name" "$force_install"
        fi
    done <<< "$enabled_plugins"

    log_success "All enabled plugins checked"
}

# 恢复所有已安装插件的符号链接
restore_all_plugin_volumes() {
    log_info "Restoring plugin volume links..."

    if [ ! -d "$PLUGINS_DATA_DIR" ]; then
        return 0
    fi

    for plugin_data_dir in "$PLUGINS_DATA_DIR"/*/; do
        if [ -d "$plugin_data_dir" ]; then
            local plugin_name=$(basename "$plugin_data_dir")
            local install_marker="$plugin_data_dir/.installed"
            local plugin_file="$PLUGINS_DEF_DIR/$plugin_name/plugin.yaml"

            if [ -f "$install_marker" ] && [ -f "$plugin_file" ]; then
                log_info "Restoring links for $plugin_name..."
                ensure_plugin_volumes "$plugin_name" "$plugin_file"
                process_plugin_env "$plugin_file" "setup"
            fi
        fi
    done

    log_success "Plugin volume links restored"
}

# ===========================================
# 服务管理
# ===========================================

# 等待依赖服务就绪
wait_for_dependency() {
    local dep_name="$1"
    local max_wait=30
    local count=0

    log_info "Waiting for dependency $dep_name to be ready..."

    while [ $count -lt $max_wait ]; do
        if is_service_running "$dep_name"; then
            log_info "Dependency $dep_name is running"
            if [ "$dep_name" = "novnc-base" ]; then
                if [ -f /tmp/novnc-env.sh ]; then
                    log_info "noVNC environment is ready"
                    return 0
                fi
            else
                return 0
            fi
        fi
        sleep 1
        count=$((count + 1))
    done

    log_warning "Dependency $dep_name not ready after ${max_wait}s"
    return 1
}

# 检查服务是否运行
is_service_running() {
    local plugin_name="$1"

    if ! pgrep -x "supervisord" > /dev/null; then
        return 1
    fi

    local status=$(supervisorctl -c "$SUPERVISOR_CONF" status "$plugin_name" 2>/dev/null | awk '{print $2}')
    [ "$status" = "RUNNING" ]
}

# 启动插件服务（Supervisor 模式）
start_plugin_service() {
    local plugin_name="$1"
    local plugin_file="$PLUGINS_DEF_DIR/$plugin_name/plugin.yaml"

    if [ ! -f "$plugin_file" ]; then
        return 0
    fi

    # 检查并等待依赖服务就绪
    local plugin_deps=$(sed -n '/^depends:/,/^[a-z]/p' "$plugin_file" 2>/dev/null | grep -E '^\s+-' | sed 's/^\s*- //')
    if [ -n "$plugin_deps" ]; then
        while IFS= read -r dep_name; do
            if [ -n "$dep_name" ] && ! wait_for_dependency "$dep_name"; then
                log_warning "Dependency $dep_name not ready, skipping $plugin_name"
                return 1
            fi
        done <<< "$plugin_deps"
    fi

    local auto_start=$(sed -n '/^service:/,/^[a-z]/p' "$plugin_file" | grep 'auto_start:' | sed 's/.*auto_start: *//' | tr -d ' ')
    local service_cmd=$(get_yaml_field_multiline "$plugin_file" "service" "command")
    local is_daemon=$(sed -n '/^service:/,/^[a-z]/p' "$plugin_file" | grep 'daemon:' | sed 's/.*daemon: *//' | tr -d ' ')
    local restart_policy=$(sed -n '/^service:/,/^[a-z]/p' "$plugin_file" | grep 'restart:' | sed 's/.*restart: *//' | tr -d ' "')
    restart_policy=${restart_policy:-true}
    local max_restarts=${max_restarts:-5}

    # 默认是 daemon 类型
    is_daemon=${is_daemon:-true}

    if [ "$auto_start" = "true" ] && [ -n "$service_cmd" ]; then
        ensure_plugin_volumes "$plugin_name" "$plugin_file"
        process_plugin_env "$plugin_file" "setup"

        # 查找第一个非注释行作为命令名
        local cmd_name=""
        while IFS= read -r line; do
            if [ -n "$line" ] && [[ ! "$line" =~ ^[[:space:]]*# ]]; then
                cmd_name=$(echo "$line" | awk '{print $1}')
                break
            fi
        done <<< "$service_cmd"

        # 如果第一行是注释，使用包装脚本执行
        if [[ "$cmd_name" == "#" ]] || [ -z "$cmd_name" ]; then
            # 多行脚本或注释开头，直接使用包装脚本
            cmd_name="bash"
        fi

        if [[ "$cmd_name" == "bash" ]] || [[ "$cmd_name" == "sh" ]] || [[ "$cmd_name" == "/bin/bash" ]] || [[ "$cmd_name" == "/bin/sh" ]]; then
            if ! command -v "$cmd_name" &>/dev/null; then
                log_warning "Shell not found: $cmd_name (skipping $plugin_name)"
                return 1
            fi
        elif [[ "$cmd_name" == /* ]]; then
            if [ ! -x "$cmd_name" ]; then
                log_warning "Service script not found or not executable: $cmd_name (skipping $plugin_name)"
                return 1
            fi
        else
            if ! command -v "$cmd_name" &>/dev/null; then
                log_warning "Service command not found: $cmd_name (skipping $plugin_name)"
                return 1
            fi
        fi

        if [ "$is_daemon" = "true" ]; then
            # daemon 类型：使用 Supervisor 管理
            if ! pgrep -x "supervisord" > /dev/null; then
                log_warning "Supervisord is not running. Start it first."
                return 1
            fi

            log_info "Starting service for $plugin_name (Supervisor mode)"

            local conf_file="$HOME/supervisor/${plugin_name}.conf"
            local log_file="$HOME/logs/${plugin_name}.log"
            local stderr_log="$HOME/logs/${plugin_name}_error.log"

            mkdir -p "$HOME/supervisor" "$HOME/logs"

            local autorestart="true"
            case "$restart_policy" in
                "false"|"no") autorestart="false" ;;
                "unexpected") autorestart="unexpected" ;;
            esac

            local env_path="$PATH"
            local script_file="$HOME/supervisor/${plugin_name}.sh"
            cat > "$script_file" << SCRIPT_HEADER
#!/bin/bash
# Auto-generated wrapper script for ${plugin_name}
# Generated at: $(date -Iseconds)

set -e

SCRIPT_HEADER

            echo "$service_cmd" >> "$script_file"
            chmod +x "$script_file"
            chown agent:agent "$script_file" 2>/dev/null || true
            local actual_cmd="$script_file"
            log_info "  Created wrapper script: $script_file"

            cat > "$conf_file" << EOF
[program:${plugin_name}]
command=$actual_cmd
directory=$HOME
user=agent
autostart=true
autorestart=${autorestart}
startretries=1
startsecs=0
stopwaitsecs=5
stopsignal=TERM
stdout_logfile=${log_file}
stdout_logfile_maxbytes=10MB
stdout_logfile_backups=3
stderr_logfile=${stderr_log}
stderr_logfile_maxbytes=10MB
stderr_logfile_backups=3
environment=PATH="${env_path}",HOME="${HOME}"
EOF

            supervisorctl -c "$SUPERVISOR_CONF" reread 2>/dev/null || true
            supervisorctl -c "$SUPERVISOR_CONF" update 2>/dev/null || true

            sleep 1

            # 对于执行完就退出的脚本（如 Docker 容器启动检查），status 会是 EXITED 而不是 RUNNING
            # 这是正常的，只要日志中没有错误信息就认为启动成功
            local status_info=$(supervisorctl -c "$SUPERVISOR_CONF" status "$plugin_name" 2>/dev/null)
            local status=$(echo "$status_info" | awk '{print $2}')
            local exit_code=$(echo "$status_info" | awk '{print $4}' | tr -d ',')

            # 检查错误日志
            local has_error=false
            if [ -f "$stderr_log" ] && [ -s "$stderr_log" ]; then
                if grep -qi "error\|failed\|错误" "$stderr_log" 2>/dev/null; then
                    has_error=true
                fi
            fi

            case "$status" in
                "RUNNING"|"STARTING")
                    log_success "Service started: $plugin_name ($status)"
                    ;;
                "EXITED")
                    # 对于一次性脚本，EXITED 是正常的
                    if [ "$has_error" = "false" ]; then
                        log_success "Service completed: $plugin_name (exit code: $exit_code)"
                    else
                        log_error "Service exited with error: $plugin_name"
                        if [ -f "$stderr_log" ]; then
                            log_info "Error log (last 5 lines):"
                            tail -5 "$stderr_log" | sed 's/^/  /'
                        fi
                    fi
                    ;;
                "BACKOFF"|"FATAL")
                    log_error "Service failed to start: $plugin_name ($status)"
                    if [ -f "$stderr_log" ]; then
                        log_info "Error log (last 5 lines):"
                        tail -5 "$stderr_log" | sed 's/^/  /'
                    fi
                    ;;
                *)
                    log_warning "Service status: $plugin_name ($status)"
                    ;;
            esac
        else
            # 非 daemon 类型：直接执行脚本，不使用 Supervisor
            log_info "Starting service for $plugin_name (oneshot mode)"

            local log_file="$HOME/logs/${plugin_name}.log"
            local stderr_log="$HOME/logs/${plugin_name}_error.log"

            mkdir -p "$HOME/logs" "$HOME/supervisor"

            # 创建临时脚本并执行
            local script_file="$HOME/supervisor/${plugin_name}.sh"

            cat > "$script_file" << SCRIPT_HEADER
#!/bin/bash
# Auto-generated oneshot script for ${plugin_name}
# Generated at: $(date -Iseconds)

set -e

SCRIPT_HEADER

            echo "$service_cmd" >> "$script_file"
            chmod +x "$script_file"
            chown agent:agent "$script_file" 2>/dev/null || true

            log_info "  Executing oneshot script: $script_file"

            # 执行脚本，捕获输出
            if "$script_file" >> "$log_file" 2>> "$stderr_log"; then
                log_success "Service completed: $plugin_name"
            else
                local exit_code=$?
                log_error "Service failed: $plugin_name (exit code: $exit_code)"
                if [ -f "$stderr_log" ] && [ -s "$stderr_log" ]; then
                    log_info "Error log (last 5 lines):"
                    tail -5 "$stderr_log" | sed 's/^/  /'
                fi
                return 1
            fi
        fi
    fi
}

# 停止插件服务
stop_plugin_service() {
    local plugin_name="$1"

    if ! pgrep -x "supervisord" > /dev/null; then
        log_warning "Supervisord is not running"
        return 1
    fi

    local status=$(supervisorctl -c "$SUPERVISOR_CONF" status "$plugin_name" 2>/dev/null | awk '{print $2}')
    if [ -z "$status" ]; then
        log_warning "Service not found: $plugin_name"
        return 0
    fi

    log_info "Stopping service: $plugin_name"
    supervisorctl -c "$SUPERVISOR_CONF" stop "$plugin_name" > /dev/null 2>&1
    log_success "Service stopped: $plugin_name"
}

# 重启插件服务
restart_plugin_service() {
    local plugin_name="$1"

    if ! pgrep -x "supervisord" > /dev/null; then
        log_warning "Supervisord is not running"
        return 1
    fi

    log_info "Restarting service: $plugin_name"
    supervisorctl -c "$SUPERVISOR_CONF" restart "$plugin_name" > /dev/null 2>&1
    log_success "Service restarted: $plugin_name"
}

# 查看服务状态
service_status() {
    local plugin_name="$1"

    if ! pgrep -x "supervisord" > /dev/null; then
        echo -e "${RED}[SUPERVISOR NOT RUNNING]${NC}"
        return 1
    fi

    if [ -n "$plugin_name" ]; then
        local info=$(supervisorctl -c "$SUPERVISOR_CONF" status "$plugin_name" 2>/dev/null)
        if [ -z "$info" ]; then
            echo -e "${RED}[NOT FOUND]${NC} $plugin_name"
            return 1
        fi

        local status=$(echo "$info" | awk '{print $2}')
        local pid=$(echo "$info" | awk '{print $4}' | tr -d ',')
        local uptime=$(echo "$info" | sed 's/.*uptime://; s/,.*//')

        case "$status" in
            "RUNNING")
                echo -e "${GREEN}[RUNNING]${NC} $plugin_name"
                ;;
            "STARTING")
                echo -e "${YELLOW}[STARTING]${NC} $plugin_name"
                ;;
            "STOPPED")
                echo -e "${RED}[STOPPED]${NC} $plugin_name"
                ;;
            "FATAL")
                echo -e "${RED}[FATAL]${NC} $plugin_name"
                ;;
            "BACKOFF")
                echo -e "${RED}[BACKOFF]${NC} $plugin_name"
                ;;
            *)
                echo -e "${YELLOW}[$status]${NC} $plugin_name"
                ;;
        esac

        echo "  PID: $pid"
        echo "  Uptime: $uptime"
        echo "  Log: $HOME/logs/${plugin_name}.log"

        local log_file="$HOME/logs/${plugin_name}.log"
        if [ -f "$log_file" ]; then
            echo "  Recent logs:"
            tail -5 "$log_file" | sed 's/^/    /'
        fi
    else
        echo -e "\n${CYAN}Supervisor Services:${NC}"
        supervisorctl -c "$SUPERVISOR_CONF" status
    fi
}

# 启动所有已启用插件的服务
start_all_services() {
    log_info "Starting plugin services..."

    if [ ! -f "$PLUGINS_CONFIG" ]; then
        return 0
    fi

    mkdir -p "$HOME/logs"

    local enabled_plugins=$(grep -B1 'enabled: true' "$PLUGINS_CONFIG" | grep 'name:' | sed 's/.*name:[[:space:]]*//' | tr -d ' ')

    local ordered_plugins=""

    while IFS= read -r plugin_name; do
        if [ -n "$plugin_name" ]; then
            local plugin_file="$PLUGINS_DEF_DIR/$plugin_name/plugin.yaml"
            local deps=$(sed -n '/^depends:/,/^[a-z]/p' "$plugin_file" 2>/dev/null | grep -E '^\s+-' | sed 's/^\s*- //')

            local is_depended=false
            while IFS= read -r other_plugin; do
                if [ -n "$other_plugin" ] && [ "$other_plugin" != "$plugin_name" ]; then
                    local other_file="$PLUGINS_DEF_DIR/$other_plugin/plugin.yaml"
                    local other_deps=$(sed -n '/^depends:/,/^[a-z]/p' "$other_file" 2>/dev/null | grep -E '^\s+-' | sed 's/^\s*- //')
                    if echo "$other_deps" | grep -q "$plugin_name"; then
                        is_depended=true
                        break
                    fi
                fi
            done <<< "$enabled_plugins"

            if [ "$is_depended" = true ]; then
                ordered_plugins="$plugin_name $ordered_plugins"
            else
                ordered_plugins="$ordered_plugins $plugin_name"
            fi
        fi
    done <<< "$enabled_plugins"

    for plugin_name in $ordered_plugins; do
        if [ -n "$plugin_name" ]; then
            start_plugin_service "$plugin_name"
        fi
    done

    log_success "Plugin services started"
}

# ===========================================
# 主入口
# ===========================================
main() {
    local command="$1"
    shift || true

    case "$command" in
        install)
            if [ -z "$1" ] || [[ "$1" == "--force" ]]; then
                log_error "Plugin name required"
                show_help
                exit 1
            fi
            local force="false"
            [ "$2" == "--force" ] && force="true"
            install_plugin "$1" "$force"
            ;;
        uninstall)
            [ -z "$1" ] && { log_error "Plugin name required"; show_help; exit 1; }
            uninstall_plugin "$1"
            ;;
        update)
            [ -z "$1" ] && { log_error "Plugin name required"; show_help; exit 1; }
            update_plugin "$1"
            ;;
        list)
            list_plugins
            ;;
        status)
            show_status
            ;;
        mirrors)
            show_mirrors
            ;;
        set-mirror)
            set_mirror "$1" "$2"
            ;;
        enable)
            log_warning "Enable command not yet implemented"
            ;;
        disable)
            log_warning "Disable command not yet implemented"
            ;;
        install-all)
            local force="false"
            [ "$1" == "--force" ] && force="true"
            install_all_plugins "$force"
            ;;
        start-services)
            start_all_services
            ;;
        start-service)
            [ -z "$1" ] && { log_error "Plugin name required"; show_help; exit 1; }
            start_plugin_service "$1"
            ;;
        stop-service)
            [ -z "$1" ] && { log_error "Plugin name required"; show_help; exit 1; }
            stop_plugin_service "$1"
            ;;
        restart-service)
            [ -z "$1" ] && { log_error "Plugin name required"; show_help; exit 1; }
            restart_plugin_service "$1"
            ;;
        service-status)
            [ -z "$1" ] && { log_error "Plugin name required"; show_help; exit 1; }
            service_status "$1"
            ;;
        restore-links)
            restore_all_plugin_volumes
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            [ -n "$command" ] && log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
