#!/bin/bash
# ===========================================
# AgentBox 插件管理 CLI
# ===========================================
# 用法：agentbox {install|uninstall|list|enable|disable|update|status|mirrors|install-all} [plugin-name]

# ⚠️ 不使用 set -e，避免单个命令失败导致脚本退出
# 使用局部错误处理

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
TOOLS_DIR="$HOME/tools"
CACHE_DIR="$HOME/cache"
SUPERVISOR_CONF="$HOME/supervisor/supervisord.conf"
VOLUME_MAP_FILE="$HOME/.volume-map"             # 卷映射缓存文件

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
  start <name>              启动指定插件服务
  stop <name>               停止指定插件服务
  restart <name>            重启指定插件服务
  ps <name>                 查看指定插件服务状态
  start-all                 启动所有已启用插件的服务

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
  agentbox start openclaw
  agentbox ps openclaw
  agentbox restart vscode-server
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
# 数据管理策略：
# - volumes 格式：源路径 或 源路径:目标路径
# - 只有源路径 → 直接创建目录
# - 有目标路径 → 创建符号链接 源 → 目标
# - 多插件声明相同源路径 → 自动检测并警告
# ===========================================

# 解析 volumes 定义
# 返回格式：源路径|目标路径（目标为空表示直接使用）
parse_volumes() {
    local plugin_file="$1"

    if [ ! -f "$plugin_file" ]; then
        return 0
    fi

    awk '/^volumes:/ {in_volumes=1; next} /^[a-zA-Z_]+:/ {in_volumes=0} in_volumes && /^\s+-/ {print}' "$plugin_file" | sed 's/^\s*- //' | while read -r line; do
        # 去除描述部分（如果有）
        line=$(echo "$line" | cut -d':' -f1-2 | xargs)

        if echo "$line" | grep -q ':'; then
            # 格式：源:目标
            local src=$(echo "$line" | cut -d':' -f1 | xargs)
            local dst=$(echo "$line" | cut -d':' -f2 | xargs)
            echo "${src}|${dst}"
        else
            # 格式：只有源
            echo "${line}|"
        fi
    done
}

# 获取已启用的插件列表
get_enabled_plugins() {
    if [ ! -f "$PLUGINS_CONFIG" ]; then
        return 0
    fi
    grep -B1 'enabled: true' "$PLUGINS_CONFIG" | grep 'name:' | sed 's/.*name:[[:space:]]*//' | tr -d ' '
}

# 生成卷映射表（检测共享关系）
generate_volume_map() {
    declare -A volume_counter
    declare -A volume_plugins

    log_info "Scanning plugin volumes..."

    for plugin in $(get_enabled_plugins); do
        local file="$PLUGINS_DEF_DIR/$plugin/plugin.yaml"
        [ -f "$file" ] || continue
        local volumes=$(parse_volumes "$file")
        while IFS='|' read -r src dst; do
            [ -z "$src" ] && continue
            local src_path="${src/#\~/$HOME}"
            volume_counter["$src_path"]=$((${volume_counter["$src_path"]:-0} + 1))
            volume_plugins["$src_path"]="${volume_plugins["$src_path"]} $plugin"
        done <<< "$volumes"
    done

    # 写入映射文件
    : > "$VOLUME_MAP_FILE"
    echo "# AgentBox Volume Map (auto-generated)" >> "$VOLUME_MAP_FILE"
    echo "# Format: src_path|count|plugins" >> "$VOLUME_MAP_FILE"
    echo "# Generated: $(date -Iseconds)" >> "$VOLUME_MAP_FILE"
    echo "" >> "$VOLUME_MAP_FILE"

    for src_path in $(echo "${!volume_counter[@]}" | tr ' ' '\n' | sort); do
        local count="${volume_counter[$src_path]}"
        local plugins="${volume_plugins[$src_path]}"

        if [ "$count" -gt 1 ]; then
            log_warning "  CONFLICT: $src_path declared by $count plugins:$plugins"
        else
            log_info "  VOLUME: $src_path ($plugins)"
        fi

        echo "$src_path|$count|$plugins" >> "$VOLUME_MAP_FILE"
    done

    log_success "Volume map generated"
}

# 确保路径存在（智能判断文件或目录）
ensure_path_exists() {
    local path="$1"

    if [ -e "$path" ]; then
        return 0
    fi

    # 根据扩展名判断是文件还是目录
    local file_patterns="\.json$ \.yaml$ \.yml$ \.toml$ \.conf$ \.env$ \.rc$ \.cfg$ \.log$ \.txt$"
    if echo "$path" | grep -qE "$file_patterns"; then
        mkdir -p "$(dirname "$path")"
        touch "$path"
        log_info "  Created file: $path"
    else
        mkdir -p "$path"
        log_info "  Created dir: $path"
    fi
}

# 设置插件卷（安装时调用）
setup_plugin_volumes() {
    local plugin_name="$1"
    local plugin_file="$2"

    local volumes=$(parse_volumes "$plugin_file")

    if [ -z "$volumes" ]; then
        return 0
    fi

    log_info "Setting up volumes for $plugin_name..."

    while IFS='|' read -r src dst; do
        [ -z "$src" ] && continue

        local src_path="${src/#\~/$HOME}"

        if [ -n "$dst" ]; then
            # 有目标路径 → 创建符号链接
            local dst_path="${dst/#\~/$HOME}"

            # 确保目标存在
            ensure_path_exists "$dst_path"

            # 处理源路径已存在的情况
            if [ -e "$src_path" ] && [ ! -L "$src_path" ]; then
                log_info "  Migrating: $src_path -> $dst_path"
                # 如果源有数据，迁移到目标
                if [ -d "$src_path" ]; then
                    cp -a "$src_path"/. "$dst_path"/ 2>/dev/null || true
                elif [ -f "$src_path" ]; then
                    cp -a "$src_path" "$dst_path" 2>/dev/null || true
                fi
                rm -rf "$src_path"
            fi

            # 创建符号链接
            ln -sf "$dst_path" "$src_path"
            log_info "  Linked: $src_path -> $dst_path"
        else
            # 无目标路径 → 直接创建目录
            ensure_path_exists "$src_path"
        fi
    done <<< "$volumes"
}

# 确保插件卷存在 (容器重启后调用)
ensure_plugin_volumes() {
    local plugin_name="$1"
    local plugin_file="$2"

    local volumes=$(parse_volumes "$plugin_file")

    if [ -z "$volumes" ]; then
        return 0
    fi

    log_info "Ensuring volumes for $plugin_name..."

    while IFS='|' read -r src dst; do
        [ -z "$src" ] && continue

        local src_path="${src/#\~/$HOME}"

        if [ -n "$dst" ]; then
            # 有目标路径 → 确保符号链接正确
            local dst_path="${dst/#\~/$HOME}"

            # 确保目标存在
            ensure_path_exists "$dst_path"

            # 检查符号链接
            if [ -L "$src_path" ]; then
                local current=$(readlink -f "$src_path" 2>/dev/null || readlink "$src_path")
                if [ "$current" != "$dst_path" ]; then
                    log_warning "  Link mismatch: $src_path -> $current (expected: $dst_path)"
                    rm -f "$src_path"
                    ln -sf "$dst_path" "$src_path"
                fi
            elif [ ! -e "$src_path" ]; then
                ln -sf "$dst_path" "$src_path"
                log_info "  Restored: $src_path -> $dst_path"
            fi
        else
            # 无目标路径 → 确保目录存在
            ensure_path_exists "$src_path"
        fi
    done <<< "$volumes"
}

# 标记插件已安装
mark_plugin_installed() {
    local plugin_name="$1"
    local markers_dir="$HOME/.plugin-markers"
    local install_marker="$markers_dir/$plugin_name.installed"

    mkdir -p "$markers_dir"

    echo "installed_at=$(date -Iseconds)" > "$install_marker"
    echo "plugin_name=$plugin_name" >> "$install_marker"
}

# ===========================================
# 插件安装管理
# ===========================================

# 执行安装命令（带错误处理和重试）
# 注意：get_install_commands 已经返回处理后的纯命令内容，直接执行即可
execute_install_commands() {
    local plugin_file="$1"
    local plugin_name="$2"

    local commands=$(get_install_commands "$plugin_file")

    if [ -z "$commands" ]; then
        log_warning "No install commands found for $plugin_name"
        return 0
    fi

    # 直接执行命令（get_yaml_list_commands 已经处理过多行块）
    execute_single_command "$commands" "$plugin_name" "$plugin_file" || return 1

    return 0
}

# 执行单个命令（带错误处理、重试和超时）
# ⚠️ 注意：会移除命令中的 set -e，避免脚本提前退出导致错误信息丢失
execute_single_command() {
    local cmd="$1"
    local plugin_name="$2"
    local plugin_file="$3"
    local timeout_seconds="${INSTALL_TIMEOUT:-1800}"  # 默认 30 分钟超时

    log_info "Executing: $(echo "$cmd" | head -1)"
    log_info "Timeout: ${timeout_seconds}s"

    local output
    local exit_code

    # 移除命令中的 set -e，替换为 set +e，确保错误能够正确捕获和显示
    local safe_cmd=$(echo "$cmd" | sed 's/set -e/set +e/g')

    # 为 npm install 命令增加额外配置，提高稳定性
    # 使用 --maxsockets 1 避免并发请求导致的问题
    safe_cmd=$(echo "$safe_cmd" | sed 's/npm install -g/npm install -g --maxsockets 1/g')

    # 使用临时文件执行多行脚本，避免 bash -c 的换行符问题
    local temp_script=$(mktemp)
    cat > "$temp_script" << 'SCRIPT_HEADER'
#!/bin/bash
# Log functions
log_info(){ echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_success(){ echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }
log_warning(){ echo -e "\033[1;33m[WARNING]\033[0m $*"; }
log_error(){ echo -e "\033[0;31m[ERROR]\033[0m $*"; }
SCRIPT_HEADER
    echo "" >> "$temp_script"
    echo "$safe_cmd" >> "$temp_script"
    chmod +x "$temp_script"

    # 使用 timeout 命令执行，避免无限挂起
    output=$(timeout "$timeout_seconds" "$temp_script" 2>&1) && exit_code=0 || exit_code=$?

    # 清理临时文件
    rm -f "$temp_script"

    if [ $exit_code -eq 124 ]; then
        # timeout 命令的退出码 124 表示超时
        log_error "Install command timed out after ${timeout_seconds}s: $plugin_name"
        log_info "You can increase timeout with: export INSTALL_TIMEOUT=600"
        return 1
    elif [ $exit_code -ne 0 ]; then
        # 检查是否是 npm 缓存问题
        if echo "$output" | grep -qE "ENOTEMPTY|EEXIST|EACCES.*\.npm"; then
            log_warning "Detected npm cache issue, attempting cleanup and retry..."

            # 清理 npm 缓存
            log_info "Cleaning npm cache..."
            rm -rf "$HOME/.npm/_cacache" 2>/dev/null || true
            npm cache clean --force 2>/dev/null || true

            # 如果是特定包安装，重试
            if [[ "$cmd" =~ npm\ install\ -g\ ([^[:space:]]+) ]]; then
                local pkg_name="${BASH_REMATCH[1]}"
                log_info "Retrying npm install: $pkg_name"
                timeout "$timeout_seconds" bash -c "$cmd" 2>&1 || {
                    log_error "Install command failed after cache cleanup: $(timeout "$timeout_seconds" bash -c "$cmd" 2>&1 | tail -5)"
                    return 1
                }
            else
                log_info "Retrying installation..."
                timeout "$timeout_seconds" bash -c "$cmd" 2>&1 || {
                    log_error "Install command failed after cache cleanup: $(timeout "$timeout_seconds" bash -c "$cmd" 2>&1 | tail -5)"
                    return 1
                }
            fi
        else
            log_error "Install command failed: $output"
            return 1
        fi
    fi

    return 0
}

# 检查插件是否已安装
is_plugin_installed() {
    local plugin_name="$1"
    local plugin_file="$2"

    local install_marker="$HOME/.plugin-markers/$plugin_name.installed"
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

    execute_post_install_commands "$plugin_file" "$plugin_name"

    mark_plugin_installed "$plugin_name"
    log_success "Plugin installed: $plugin_name"
}

# 执行 post_install 命令
execute_post_install_commands() {
    local plugin_file="$1"
    local plugin_name="$2"

    local commands=$(get_yaml_list_commands "$plugin_file" "post_install")

    if [ -z "$commands" ]; then
        return 0
    fi

    log_info "Running post-install commands..."

    local current_cmd=""
    local in_multiline=false

    while IFS= read -r line; do
        # 检查是否是新的列表项（以 - 开头）
        if [[ "$line" =~ ^-[[:space:]] ]]; then
            # 如果之前有累积的命令，执行它
            if [ -n "$current_cmd" ]; then
                execute_post_install_single_command "$current_cmd"
            fi
            # 开始新的命令
            local item_content=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//')
            if [[ "$item_content" == "|" ]] || [[ "$item_content" == "|-" ]] || [[ "$item_content" == "|+" ]]; then
                in_multiline=true
                current_cmd=""
            else
                in_multiline=false
                current_cmd="$item_content"
            fi
        elif [ "$in_multiline" = true ] || [ -n "$current_cmd" ]; then
            # 多行块内容或续行
            if [ -z "$current_cmd" ]; then
                current_cmd="$line"
            else
                current_cmd="${current_cmd}"$'\n'"$line"
            fi
        fi
    done <<< "$commands"

    # 执行最后一个命令
    if [ -n "$current_cmd" ]; then
        execute_post_install_single_command "$current_cmd"
    fi

    return 0
}

# 执行单个 post_install 命令
execute_post_install_single_command() {
    local cmd="$1"

    # 跳过注释
    if [[ "$cmd" =~ ^[[:space:]]*# ]]; then
        return 0
    fi

    log_info "  $(echo "$cmd" | head -1)"
    eval "$cmd"
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
        # 将命令作为单个脚本块执行（支持 if/else/fi 等多行语法）
        log_info "Executing uninstall script..."
        execute_single_command "$commands" "$plugin_name" "$plugin_file"
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

    # 将命令作为单个脚本块执行（支持 if/else/fi 等多行语法）
    log_info "Executing update script..."
    execute_single_command "$commands" "$plugin_name" "$plugin_file"

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

# 安装所有已启用的插件（并行安装 + 依赖感知）
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

    # 按依赖层级分组安装
    log_info "Analyzing dependency layers for installation..."
    local layers=$(get_dependency_layers "$enabled_plugins")

    local total_installed=0
    local total_failed=0
    local failed_plugins=()

    # 逐层安装（层内并行，层间串行）
    local layer_num=0
    while IFS= read -r layer; do
        [ -z "$layer" ] && continue
        ((layer_num++))

        log_info "Installing Layer $layer_num: $layer"

        local layer_plugins=($layer)
        local temp_results=$(mktemp -d)

        # 并行安装当前层的插件
        for plugin_name in "${layer_plugins[@]}"; do
            [ -z "$plugin_name" ] && continue

            # 后台安装每个插件
            (
                local result_file="$temp_results/$plugin_name"
                local log_file="$temp_results/${plugin_name}.log"

                if install_plugin "$plugin_name" "$force_install" > "$log_file" 2>&1; then
                    echo "success" > "$result_file"
                else
                    echo "failed" > "$result_file"
                fi
            ) &
            log_info "  Started: $plugin_name (PID: $!)"
        done

        # 等待当前层所有安装完成
        log_info "  Waiting for layer $layer_num installations..."
        wait

        # 统计结果
        for plugin_name in "${layer_plugins[@]}"; do
            [ -z "$plugin_name" ] && continue
            local result_file="$temp_results/$plugin_name"
            local log_file="$temp_results/${plugin_name}.log"

            if [ -f "$result_file" ]; then
                if [ "$(cat "$result_file")" = "success" ]; then
                    ((total_installed++))
                    log_success "  Installed: $plugin_name"
                else
                    ((total_failed++))
                    failed_plugins+=("$plugin_name")
                    log_error "  Failed: $plugin_name"
                    # 显示最后几行日志
                    if [ -f "$log_file" ]; then
                        tail -3 "$log_file" | sed 's/^/    /'
                    fi
                fi
            fi
        done

        # 清理临时文件
        rm -rf "$temp_results"

    done <<< "$layers"

    log_info "Installation summary: $total_installed installed, $total_failed failed"

    if [ ${#failed_plugins[@]} -gt 0 ]; then
        log_warning "Failed plugins: ${failed_plugins[*]}"
        log_info "Retry with: agentbox install <plugin-name>"
    fi

    log_success "Plugin installation completed"
    return 0
}

# 恢复所有已安装插件的卷
restore_all_plugin_volumes() {
    log_info "Restoring plugin volumes..."

    local markers_dir="$HOME/.plugin-markers"

    if [ ! -d "$markers_dir" ]; then
        return 0
    fi

    for marker_file in "$markers_dir"/*.installed; do
        if [ -f "$marker_file" ]; then
            local plugin_name=$(basename "$marker_file" .installed)
            local plugin_file="$PLUGINS_DEF_DIR/$plugin_name/plugin.yaml"

            if [ -f "$plugin_file" ]; then
                log_info "Restoring volumes for $plugin_name..."
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
    local max_wait=120
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

        # 检查 Supervisor 配置是否已存在
        local conf_file="$HOME/supervisor/${plugin_name}.conf"
        local config_exists=false
        [ -f "$conf_file" ] && config_exists=true

        # 如果配置已存在且服务正在运行/启动中，跳过
        if [ "$config_exists" = "true" ] && [ "$is_daemon" = "true" ]; then
            local svc_status=$(supervisorctl -c "$SUPERVISOR_CONF" status "$plugin_name" 2>/dev/null || echo "")
            local svc_state=$(echo "$svc_status" | awk '{print $2}')

            # RUNNING 或 STARTING 都跳过
            if [ "$svc_state" = "RUNNING" ] || [ "$svc_state" = "STARTING" ]; then
                log_info "Service $plugin_name already $svc_state (skip)"
                return 0
            fi
        fi

        # 启动前清理旧进程（防止孤儿进程）
        log_info "Cleaning up orphan processes for $plugin_name..."

        # 1. 从 service_cmd 中提取进程名用于清理
        local proc_name=""
        local is_script_service=false

        # 处理 bash -c '...' 或 sh -c '...' 的情况，提取内部命令
        if [[ "$service_cmd" =~ (bash|sh|/bin/bash|/bin/sh)[[:space:]]+-c[[:space:]]+[\'\"](.*)[\'\"] ]]; then
            local inner_cmd="${BASH_REMATCH[2]}"
            proc_name=$(echo "$inner_cmd" | awk '{print $1}' | xargs basename 2>/dev/null || echo "$inner_cmd" | awk '{print $1}')
        else
            proc_name=$(echo "$service_cmd" | awk '{print $1}' | xargs basename 2>/dev/null || echo "$service_cmd" | awk '{print $1}')
        fi

        # 检查是否是脚本类型服务（bash/sh 执行脚本文件）
        if [[ "$proc_name" == "bash" ]] || [[ "$proc_name" == "sh" ]] || [[ "$proc_name" == "/bin/bash" ]] || [[ "$proc_name" == "/bin/sh" ]]; then
            is_script_service=true
            # 对于脚本服务，提取脚本路径作为精确匹配
            local script_path=$(echo "$service_cmd" | awk '{print $2}' 2>/dev/null || true)
            if [ -n "$script_path" ]; then
                # 使用脚本路径匹配（更精确）
                local script_pids=$(pgrep -f "$script_path" 2>/dev/null || true)
                if [ -n "$script_pids" ]; then
                    log_info "  Killing script processes ($script_path):$script_pids"
                    for pid in $script_pids; do
                        kill -9 "$pid" 2>/dev/null || true
                    done
                    sleep 1
                fi
            fi
        fi

        # 清理同名进程（仅对非 shell 进程，避免误杀所有 bash 进程）
        if [ "$is_script_service" = "false" ] && [ -n "$proc_name" ] && [ "$proc_name" != "" ]; then
            # 排除通用 shell 名称，避免误杀
            local shell_names="bash sh zsh fish dash ksh tcsh csh"
            local is_shell=false
            for shell in $shell_names; do
                if [ "$proc_name" = "$shell" ]; then
                    is_shell=true
                    break
                fi
            done

            if [ "$is_shell" = "false" ]; then
                # 匹配规则：进程名后必须跟空格/参数或是行尾
                local proc_pids=$(pgrep -f "(^|[[:space:]/])${proc_name}([[:space:]]|$)" 2>/dev/null || true)
                if [ -n "$proc_pids" ]; then
                    # 二次过滤：检查实际的进程名，确保精确匹配
                    local filtered_pids=""
                    for pid in $proc_pids; do
                        local cmd=$(ps -o comm= -p "$pid" 2>/dev/null || echo "")
                        local base_cmd=$(basename "$cmd" 2>/dev/null || echo "")
                        if [ "$base_cmd" = "$proc_name" ]; then
                            filtered_pids="$filtered_pids $pid"
                        fi
                    done

                    if [ -n "$filtered_pids" ]; then
                        log_info "  Killing $proc_name processes:$filtered_pids"
                        for pid in $filtered_pids; do
                            pkill -9 -P "$pid" 2>/dev/null || true
                            kill -9 "$pid" 2>/dev/null || true
                        done
                        sleep 1
                    fi
                fi
            fi
        fi

        # 2. 使用 Supervisor 停止服务（如果存在配置）
        if pgrep -x "supervisord" > /dev/null; then
            local svc_status=$(supervisorctl -c "$SUPERVISOR_CONF" status "$plugin_name" 2>/dev/null | awk '{print $1, $2}')
            local svc_name=$(echo "$svc_status" | awk '{print $1}')
            local svc_state=$(echo "$svc_status" | awk '{print $2}')

            # 只有服务已存在于 Supervisor 中才执行停止
            if [ "$svc_name" = "$plugin_name:" ]; then
                if [ "$svc_state" = "RUNNING" ] || [ "$svc_state" = "STARTING" ] || [ "$svc_state" = "BACKOFF" ] || [ "$svc_state" = "FATAL" ]; then
                    log_info "  Stopping existing service via Supervisor..."
                    supervisorctl -c "$SUPERVISOR_CONF" stop "$plugin_name" > /dev/null 2>&1
                    sleep 2

                    # Supervisor 停止后，清理 wrapper 脚本的残留进程
                    local wrapper_script="$HOME/supervisor/${plugin_name}.sh"
                    if [ -f "$wrapper_script" ]; then
                        local wrapper_pids=$(pgrep -f "$wrapper_script" 2>/dev/null || true)
                        if [ -n "$wrapper_pids" ]; then
                            log_info "  Killing wrapper processes: $wrapper_pids"
                            for pid in $wrapper_pids; do
                                pkill -9 -P "$pid" 2>/dev/null || true
                                kill -9 "$pid" 2>/dev/null || true
                            done
                            sleep 1
                        fi
                    fi
                fi
            fi
        fi

        # 3. 清理插件锁文件（如果存在）
        # 通用锁文件路径模式：~/.{plugin_name}/*.lock
        local lock_dir="$HOME/.${plugin_name}"
        if [ -d "$lock_dir" ]; then
            local lock_files=$(find "$lock_dir" -name "*.lock" -type f 2>/dev/null || true)
            if [ -n "$lock_files" ]; then
                log_info "  Removing stale lock files in $lock_dir"
                echo "$lock_files" | while read -r lock_file; do
                    rm -f "$lock_file"
                done
            fi
        fi

        # 4. 额外等待，确保资源完全释放
        sleep 1

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

            local conf_file="$HOME/supervisor/${plugin_name}.conf"
            local log_file="$HOME/logs/${plugin_name}.log"
            local stderr_log="$HOME/logs/${plugin_name}_error.log"

            mkdir -p "$HOME/supervisor" "$HOME/logs"

            # 检查配置是否已存在
            if [ -f "$conf_file" ]; then
                # 配置已存在，只需启动服务
                local current_status=$(supervisorctl -c "$SUPERVISOR_CONF" status "$plugin_name" 2>/dev/null | awk '{print $2}')

                case "$current_status" in
                    "RUNNING"|"STARTING")
                        log_success "Service $plugin_name already $current_status"
                        return 0
                        ;;
                    "STOPPED"|"EXITED"|"FATAL"|"BACKOFF")
                        log_info "Starting existing service: $plugin_name"
                        supervisorctl -c "$SUPERVISOR_CONF" start "$plugin_name" > /dev/null 2>&1
                        sleep 2
                        local new_status=$(supervisorctl -c "$SUPERVISOR_CONF" status "$plugin_name" 2>/dev/null | awk '{print $2}')
                        if [ "$new_status" = "RUNNING" ] || [ "$new_status" = "STARTING" ]; then
                            log_success "Service started: $plugin_name"
                        else
                            log_error "Failed to start: $plugin_name ($new_status)"
                        fi
                        return 0
                        ;;
                esac
            fi

            # 配置不存在，创建新配置
            log_info "Creating service for $plugin_name (Supervisor mode)"

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

# ⚠️ 不使用 set -e，避免脚本失败

exec $service_cmd
SCRIPT_HEADER
            chmod +x "$script_file"
            chown agent:agent "$script_file" 2>/dev/null || true
            local actual_cmd="$script_file"
            log_info "  Created wrapper script: $script_file"

            cat > "$conf_file" << EOF
[program:${plugin_name}]
command=$actual_cmd
directory=$HOME
user=agent
autostart=false
autorestart=${autorestart}
startretries=3
startsecs=2
stopwaitsecs=5
stopsignal=KILL
killasgroup=true
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

            # 显式启动服务
            supervisorctl -c "$SUPERVISOR_CONF" start "$plugin_name" > /dev/null 2>&1

            sleep 2

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

# ⚠️ 不使用 set -e，避免脚本失败

# Log functions
log_info(){ echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_success(){ echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }
log_warning(){ echo -e "\033[1;33m[WARNING]\033[0m $*"; }
log_error(){ echo -e "\033[0;31m[ERROR]\033[0m $*"; }

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
    local plugin_file="$PLUGINS_DEF_DIR/$plugin_name/plugin.yaml"

    if [ ! -f "$plugin_file" ]; then
        log_warning "Plugin definition not found: $plugin_name"
        return 1
    fi

    # 检查服务类型（daemon 还是 oneshot）
    local is_daemon=$(sed -n '/^service:/,/^[a-z]/p' "$plugin_file" | grep 'daemon:' | sed 's/.*daemon: *//' | tr -d ' "')
    is_daemon=${is_daemon:-true}  # 默认是 daemon

    # 1. 对于 daemon 服务，优先使用 Supervisor 停止
    # ⚠️ 注意：daemon 服务不使用 stop_command，由 Supervisor 管理停止
    if [ "$is_daemon" = "true" ] && pgrep -x "supervisord" > /dev/null; then
        local status=$(supervisorctl -c "$SUPERVISOR_CONF" status "$plugin_name" 2>/dev/null | awk '{print $2}')
        if [ -n "$status" ] && [ "$status" != "STOPPED" ] && [ "$status" != "EXITED" ]; then
            log_info "Stopping service: $plugin_name (Supervisor daemon)"
            # supervisorctl stop 会：
            # 1. 发送 SIGTERM 信号
            # 2. 等待 stopwaitsecs (10 秒)
            # 3. 如果还在，发送 SIGKILL
            # 4. 杀死整个进程组 (killasgroup=true)
            supervisorctl -c "$SUPERVISOR_CONF" stop "$plugin_name" > /dev/null 2>&1
            
            # 循环等待进程停止（最多 10 秒）
            local wait_count=0
            while [ $wait_count -lt 10 ]; do
                sleep 1
                local new_status=$(supervisorctl -c "$SUPERVISOR_CONF" status "$plugin_name" 2>/dev/null | awk '{print $2}')
                if [ "$new_status" = "STOPPED" ] || [ "$new_status" = "EXITED" ]; then
                    log_success "Service stopped: $plugin_name"
                    return 0
                elif [ "$new_status" = "FATAL" ]; then
                    log_error "Service failed to stop: $plugin_name ($new_status)"
                    return 1
                fi
                ((wait_count++))
            done
            
            # 超时警告
            log_warning "Service stop timeout: $plugin_name (may still be stopping)"
            return 0
        else
            log_info "Service already stopped: $plugin_name ($status)"
            return 0
        fi
    fi

    # 2. 对于 oneshot 服务，使用自定义 stop_command
    local stop_cmd=$(get_yaml_field_multiline "$plugin_file" "service" "stop_command")
    if [ -n "$stop_cmd" ] && [ "$is_daemon" = "false" ]; then
        log_info "Stopping service for $plugin_name (custom stop_command)..."
        
        # 创建临时脚本执行
        local script_file="$HOME/supervisor/${plugin_name}_stop.sh"
        cat > "$script_file" << EOF
#!/bin/bash
# ⚠️ 不使用 set -e
$stop_cmd
EOF
        chmod +x "$script_file"
        
        if "$script_file"; then
            log_success "Service stopped: $plugin_name"
            rm -f "$script_file"
            return 0
        else
            log_error "Failed to stop service: $plugin_name"
            rm -f "$script_file"
            return 1
        fi
    fi

    # 3. Fallback: 尝试通过进程名停止
    local service_cmd=$(get_yaml_field_multiline "$plugin_file" "service" "command")
    if [ -n "$service_cmd" ]; then
        log_info "Stopping processes for $plugin_name (fallback)..."
        local stopped=0
        
        # 根据命令名停止进程
        if echo "$service_cmd" | grep -q "code-server"; then
            pkill -f "code-server" 2>/dev/null && stopped=1
        elif echo "$service_cmd" | grep -q "copaw app"; then
            pkill -f "copaw" 2>/dev/null && stopped=1
        elif echo "$service_cmd" | grep -q "ttyd"; then
            pkill -f "ttyd" 2>/dev/null && stopped=1
        elif echo "$service_cmd" | grep -q "openclaw"; then
            pkill -f "openclaw" 2>/dev/null && stopped=1
        elif echo "$service_cmd" | grep -q "hiclaw"; then
            docker stop hiclaw-manager 2>/dev/null && stopped=1
        elif echo "$service_cmd" | grep -q "start-novnc"; then
            ~/tools/novnc-scripts/stop-novnc.sh 2>/dev/null && stopped=1
        elif echo "$service_cmd" | grep -q "board"; then
            pkill -f "board-server" 2>/dev/null && stopped=1
        elif echo "$service_cmd" | grep -q "Skills-Manager\|AppRun"; then
            pkill -f "AppRun" 2>/dev/null && stopped=1
        fi
        
        if [ $stopped -eq 1 ]; then
            log_success "Service stopped: $plugin_name"
            return 0
        fi
    fi

    log_warning "No stop method found for $plugin_name"
    return 0
}

# 重启插件服务
restart_plugin_service() {
    local plugin_name="$1"
    local plugin_file="$PLUGINS_DEF_DIR/$plugin_name/plugin.yaml"

    if [ ! -f "$plugin_file" ]; then
        log_warning "Plugin definition not found: $plugin_name"
        return 1
    fi

    # 检查服务类型（daemon 还是 oneshot）
    local is_daemon=$(sed -n '/^service:/,/^[a-z]/p' "$plugin_file" | grep 'daemon:' | sed 's/.*daemon: *//' | tr -d ' "')
    is_daemon=${is_daemon:-true}  # 默认是 daemon

    # 1. 对于 daemon 服务且使用 Supervisor，使用 supervisorctl restart
    # ⚠️ 注意：daemon 服务不使用 restart_command，由 Supervisor 管理重启
    if [ "$is_daemon" = "true" ] && pgrep -x "supervisord" > /dev/null; then
        local status=$(supervisorctl -c "$SUPERVISOR_CONF" status "$plugin_name" 2>/dev/null | awk '{print $2}')
        if [ -n "$status" ]; then
            log_info "Restarting service: $plugin_name (Supervisor daemon)"
            
            # ✅ 先完全停止（等待进程完全退出）
            log_info "Stopping service: $plugin_name..."

            # 获取停止前的 PID（用于后续清理）
            local pre_stop_pid=$(supervisorctl -c "$SUPERVISOR_CONF" status "$plugin_name" 2>/dev/null | grep -oP 'pid \K\d+' || true)
            log_info "  Pre-stop PID: $pre_stop_pid"

            supervisorctl -c "$SUPERVISOR_CONF" stop "$plugin_name" > /dev/null 2>&1

            # 循环等待进程完全停止（最多 15 秒）
            local wait_count=0
            while [ $wait_count -lt 15 ]; do
                sleep 1
                local current_status=$(supervisorctl -c "$SUPERVISOR_CONF" status "$plugin_name" 2>/dev/null | awk '{print $2}')
                if [ "$current_status" = "STOPPED" ] || [ "$current_status" = "EXITED" ]; then
                    log_info "Service stopped: $plugin_name"
                    break
                fi
                ((wait_count++))
            done

            # ✅ 强制杀死残留进程（如果有）
            # 清理停止前的 PID 及其子进程（可能是孤儿进程）
            if [ -n "$pre_stop_pid" ] && kill -0 "$pre_stop_pid" 2>/dev/null; then
                log_info "  Killing old process: $pre_stop_pid"
                kill -9 "$pre_stop_pid" 2>/dev/null || true
                pkill -9 -P "$pre_stop_pid" 2>/dev/null || true
                sleep 1
            fi

            # 清理 wrapper 脚本的残留进程
            local wrapper_script="$HOME/supervisor/${plugin_name}.sh"
            if [ -f "$wrapper_script" ]; then
                local wrapper_pids=$(pgrep -f "$wrapper_script" 2>/dev/null || true)
                if [ -n "$wrapper_pids" ]; then
                    log_info "  Killing wrapper processes: $wrapper_pids"
                    for pid in $wrapper_pids; do
                        # 排除刚获取的 pre_stop_pid，避免重复杀死
                        if [ "$pid" != "$pre_stop_pid" ]; then
                            pkill -9 -P "$pid" 2>/dev/null || true
                            kill -9 "$pid" 2>/dev/null || true
                        fi
                    done
                    sleep 1
                fi
            fi
            sleep 2
            
            # ✅ 然后启动新进程
            log_info "Starting service: $plugin_name..."
            supervisorctl -c "$SUPERVISOR_CONF" start "$plugin_name" > /dev/null 2>&1
            
            # 循环等待启动（最多 10 秒）
            wait_count=0
            while [ $wait_count -lt 10 ]; do
                sleep 1
                local new_status=$(supervisorctl -c "$SUPERVISOR_CONF" status "$plugin_name" 2>/dev/null | awk '{print $2}')
                if [ "$new_status" = "RUNNING" ]; then
                    log_success "Service restarted: $plugin_name"
                    return 0
                elif [ "$new_status" = "FATAL" ] || [ "$new_status" = "BACKOFF" ]; then
                    log_error "Service failed to restart: $plugin_name ($new_status)"
                    return 1
                fi
                ((wait_count++))
            done
            
            # 超时但可能仍在启动
            log_warning "Service restart timeout: $plugin_name (may still be starting)"
            return 0
        fi
    fi

    # 2. 对于 oneshot 服务，使用自定义 restart_command
    local restart_cmd=$(get_yaml_field_multiline "$plugin_file" "service" "restart_command")
    if [ -n "$restart_cmd" ] && [ "$is_daemon" = "false" ]; then
        log_info "Restarting service for $plugin_name (custom restart_command)..."
        
        local script_file="$HOME/supervisor/${plugin_name}_restart.sh"
        cat > "$script_file" << EOF
#!/bin/bash
# ⚠️ 不使用 set -e
$restart_cmd
EOF
        chmod +x "$script_file"
        
        if "$script_file"; then
            log_success "Service restarted: $plugin_name"
            rm -f "$script_file"
            return 0
        else
            log_error "Failed to restart service: $plugin_name"
            rm -f "$script_file"
            return 1
        fi
    fi

    # 3. 默认：先停止再启动
    log_info "Restarting service: $plugin_name (stop + start)"
    stop_plugin_service "$plugin_name"
    sleep 2
    start_plugin_service "$plugin_name"
    
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

# 启动所有已启用插件的服务（并行启动 + 拓扑排序）
start_all_services() {
    log_info "Starting plugin services..."

    if [ ! -f "$PLUGINS_CONFIG" ]; then
        return 0
    fi

    mkdir -p "$HOME/logs"

    local enabled_plugins=$(grep -B1 'enabled: true' "$PLUGINS_CONFIG" | grep 'name:' | sed 's/.*name:[[:space:]]*//' | tr -d ' ')

    if [ -z "$enabled_plugins" ]; then
        log_warning "No enabled plugins found in config"
        return 0
    fi

    # 按依赖层级分组（同一层可并行启动）
    log_info "Analyzing dependency layers..."
    local layers=$(get_dependency_layers "$enabled_plugins")

    local total_started=0
    local total_failed=0
    local failed_services=()

    # 逐层启动（层内并行，层间串行）
    local layer_num=0
    while IFS= read -r layer; do
        [ -z "$layer" ] && continue
        ((layer_num++))

        log_info "Layer $layer_num: $layer"

        # 并行启动当前层的服务
        local pids=""
        local layer_plugins=($layer)
        local temp_results=$(mktemp -d)

        for plugin_name in "${layer_plugins[@]}"; do
            [ -z "$plugin_name" ] && continue

            # 后台启动每个服务
            (
                local result_file="$temp_results/$plugin_name"
                if start_plugin_service "$plugin_name"; then
                    echo "success" > "$result_file"
                else
                    echo "failed" > "$result_file"
                fi
            ) &
            pids="$pids $!"
        done

        # 等待当前层所有服务启动完成
        if [ -n "$pids" ]; then
            log_info "  Waiting for layer $layer_num services to start..."
            wait $pids 2>/dev/null || true
        fi

        # 统计结果
        for plugin_name in "${layer_plugins[@]}"; do
            [ -z "$plugin_name" ] && continue
            local result_file="$temp_results/$plugin_name"
            if [ -f "$result_file" ]; then
                if [ "$(cat "$result_file")" = "success" ]; then
                    ((total_started++))
                else
                    ((total_failed++))
                    failed_services+=("$plugin_name")
                    log_warning "  Failed: $plugin_name"
                fi
            fi
        done

        # 清理临时文件
        rm -rf "$temp_results"

    done <<< "$layers"

    log_info "Service startup summary: $total_started started, $total_failed failed"

    if [ ${#failed_services[@]} -gt 0 ]; then
        log_warning "Failed services: ${failed_services[*]}"
        log_info "Retry with: agentbox start <plugin-name>"
    fi

    log_success "Service startup completed"
    return 0
}

# 获取依赖层级（同一层可并行启动）
# 输入：插件列表（空格分隔）
# 输出：每行一层，每层包含可并行启动的插件
get_dependency_layers() {
    local plugins="$1"

    # 使用关联数组存储依赖关系
    declare -A deps_map      # plugin -> 依赖列表
    declare -A in_degree     # plugin -> 入度
    declare -A processed     # plugin -> 是否已处理

    # 初始化
    for plugin in $plugins; do
        in_degree[$plugin]=0
        deps_map[$plugin]=""
        processed[$plugin]=false
    done

    # 构建依赖图
    for plugin in $plugins; do
        local plugin_file="$PLUGINS_DEF_DIR/$plugin/plugin.yaml"
        if [ -f "$plugin_file" ]; then
            local plugin_deps=$(sed -n '/^depends:/,/^[a-z]/p' "$plugin_file" 2>/dev/null | grep -E '^\s+-' | sed 's/^\s*- //' | tr '\n' ' ')
            for dep in $plugin_deps; do
                if [ -n "$dep" ] && [[ " $plugins " == *" $dep "* ]]; then
                    # dep -> plugin (dep 必须在 plugin 之前)
                    deps_map[$dep]="${deps_map[$dep]} $plugin"
                    ((in_degree[$plugin]++))
                fi
            done
        fi
    done

    # 按层输出（BFS）
    local remaining="$plugins"
    while [ -n "$(echo "$remaining" | tr -d ' ')" ]; do
        local current_layer=""

        # 找出当前层（入度为 0 且未处理）
        for plugin in $remaining; do
            [ -z "$plugin" ] && continue
            if [ "${in_degree[$plugin]}" -eq 0 ] && [ "${processed[$plugin]}" = "false" ]; then
                current_layer="$current_layer $plugin"
            fi
        done

        # 如果没有找到，说明可能有环或剩余的都是有依赖的
        if [ -z "$(echo "$current_layer" | tr -d ' ')" ]; then
            # 强制输出剩余的（可能是循环依赖）
            for plugin in $remaining; do
                [ -z "$plugin" ] && continue
                if [ "${processed[$plugin]}" = "false" ]; then
                    current_layer="$current_layer $plugin"
                fi
            done
        fi

        # 输出当前层
        echo "$current_layer" | xargs

        # 标记为已处理，并更新依赖它们的插件的入度
        for plugin in $current_layer; do
            [ -z "$plugin" ] && continue
            processed[$plugin]=true
            # 减少依赖此插件的入度
            for dependent in ${deps_map[$plugin]}; do
                [ -n "$dependent" ] && ((in_degree[$dependent]--))
            done
        done

        # 更新剩余列表
        local new_remaining=""
        for plugin in $remaining; do
            if [ "${processed[$plugin]}" = "false" ]; then
                new_remaining="$new_remaining $plugin"
            fi
        done
        remaining="$new_remaining"
    done
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
        start-all)
            start_all_services
            ;;
        start)
            [ -z "$1" ] && { log_error "Plugin name required"; show_help; exit 1; }
            start_plugin_service "$1"
            ;;
        stop)
            [ -z "$1" ] && { log_error "Plugin name required"; show_help; exit 1; }
            stop_plugin_service "$1"
            ;;
        restart)
            [ -z "$1" ] && { log_error "Plugin name required"; show_help; exit 1; }
            restart_plugin_service "$1"
            ;;
        ps)
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
