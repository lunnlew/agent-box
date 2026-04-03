#!/bin/bash
# ===========================================
# AgentBox 共享函数库
# ===========================================
# 提供通用函数供 entrypoint.sh 和 plugin-manager.sh 使用
# 用法：source /opt/lib.sh

# ===========================================
# 颜色定义
# ===========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ===========================================
# 日志函数
# ===========================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ===========================================
# YAML 解析函数
# ===========================================

# 内部函数：处理多行块内容（|, |-, |+）
# 用法：_parse_multiline_block <input_lines>
# 输出：解析后的多行内容
_parse_multiline_block() {
    local result=""
    local in_block=false
    local base_indent=-1

    while IFS= read -r line; do
        if [ -z "$line" ] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
            if [ "$in_block" = true ] && [ -n "$result" ]; then
                result="${result}"$'\n'
            fi
            continue
        fi

        if [ "$in_block" = false ]; then
            local line_indent=$(echo "$line" | sed 's/[^ \t].*//' | wc -c)
            if [ $base_indent -eq -1 ] && [ $line_indent -gt 0 ]; then
                base_indent=$line_indent
                in_block=true
                local stripped=$(echo "$line" | sed 's/^[[:space:]]*//')
                result="$stripped"
            fi
        else
            local line_indent=$(echo "$line" | sed 's/[^ \t].*//' | wc -c)
            if [ $line_indent -ge $base_indent ]; then
                local stripped=$(echo "$line" | sed 's/^[[:space:]]*//')
                if [ -n "$result" ]; then
                    result="${result}"$'\n'"$stripped"
                else
                    result="$stripped"
                fi
            else
                break
            fi
        fi
    done

    echo "$result"
}

# 解析 YAML 列表命令（支持多行块语法 |, |-, |+）
# 用法：get_yaml_list_commands <file> <section>
# 例如：get_yaml_list_commands plugin.yaml install
get_yaml_list_commands() {
    local plugin_file="$1"
    local section="$2"

    if [ ! -f "$plugin_file" ]; then
        return 1
    fi

    # 提取 section 内容（到下一个顶级字段前，不包括该字段）
    local section_content
    section_content=$(awk "/^${section}:/{found=1; next} /^[a-zA-Z_]+:/{found=0} found" "$plugin_file")

    if [ -z "$section_content" ]; then
        return 0
    fi

    local in_block=false
    local block_cmd=""

    while IFS= read -r line; do
        if [ -z "$line" ] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
            if [ "$in_block" = true ]; then
                block_cmd="${block_cmd}"$'\n'
            fi
            continue
        fi

        # 跳过顶级字段（段落边界）
        if [[ "$line" =~ ^[a-zA-Z_]+: ]]; then
            break
        fi

        # 跳过顶级注释（以#开头且没有缩进）
        if [[ "$line" =~ ^# ]]; then
            continue
        fi

        if [[ "$line" =~ ^[[:space:]]*-[[:space:]] ]]; then
            if [ "$in_block" = true ] && [ -n "$block_cmd" ]; then
                echo "$block_cmd"
                block_cmd=""
                in_block=false
            fi

            local item_content
            item_content=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//')

            if [[ "$item_content" == "|" ]] || [[ "$item_content" == "|-" ]] || [[ "$item_content" == "|+" ]]; then
                in_block=true
                block_cmd=""
            else
                echo "$item_content"
            fi
        elif [ "$in_block" = true ]; then
            # 在多行块中，检查是否遇到顶级注释或字段（结束标记）
            if [[ "$line" =~ ^[a-zA-Z_#] ]]; then
                break
            fi
            local stripped
            stripped=$(echo "$line" | sed 's/^[[:space:]]*//')
            if [ -n "$stripped" ]; then
                if [ -z "$block_cmd" ]; then
                    block_cmd="$stripped"
                else
                    block_cmd="${block_cmd}"$'\n'"$stripped"
                fi
            fi
        fi
    done <<< "$section_content"

    if [ "$in_block" = true ] && [ -n "$block_cmd" ]; then
        echo "$block_cmd"
    fi
}

# 解析 YAML 字段值（支持多行块语法 |, |-, |+）
# 用法：get_yaml_field_multiline <file> <section> <field>
# 例如：get_yaml_field_multiline plugin.yaml service command
get_yaml_field_multiline() {
    local plugin_file="$1"
    local section="$2"
    local field="$3"

    if [ ! -f "$plugin_file" ]; then
        return 1
    fi

    local section_start=$(grep -n "^${section}:" "$plugin_file" | head -1 | cut -d: -f1)
    if [ -z "$section_start" ]; then
        return 1
    fi

    local next_section_start=$(tail -n +$((section_start + 1)) "$plugin_file" | grep -n "^[a-zA-Z_]*:" | head -1 | cut -d: -f1)
    if [ -z "$next_section_start" ]; then
        local section_end=$(wc -l < "$plugin_file")
    else
        local section_end=$((section_start + next_section_start - 1))
    fi

    local section_content=$(sed -n "${section_start},${section_end}p" "$plugin_file")

    local field_line=$(echo "$section_content" | grep -n "^[[:space:]]*${field}:" | head -1)
    if [ -z "$field_line" ]; then
        return 1
    fi

    local field_line_num=$(echo "$field_line" | cut -d: -f1)
    local field_content=$(echo "$field_line" | sed 's/^[0-9]*:[[:space:]]*//' | sed 's/^'"${field}"':[[:space:]]*//')

    if [[ "$field_content" == "|" ]] || [[ "$field_content" == "|-" ]] || [[ "$field_content" == "|+" ]]; then
        echo "$(echo "$section_content" | tail -n +$((field_line_num + 1)))" | _parse_multiline_block
    else
        echo "$field_content" | sed 's/^"//;s/"$//'
    fi
}

# 解析 YAML 单个字段值
# 用法：parse_yaml_field <file> <field>
parse_yaml_field() {
    local plugin_file="$1"
    local field="$2"

    if [ ! -f "$plugin_file" ]; then
        return 1
    fi

    grep "^${field}:" "$plugin_file" | head -1 | sed 's/^[^:]*: *//' | tr -d '"'
}

# ===========================================
# PATH 管理函数
# ===========================================

# 将路径添加到 PATH 和 .bashrc（防重复）
# 用法：_add_to_path <path> [write_bashrc]
#   write_bashrc: true(默认) 写入 .bashrc, false 只添加到当前 PATH
_add_to_path() {
    local raw_path="$1"
    local write_bashrc="${2:-true}"

    # 展开路径
    local expanded_path="${raw_path/#\~/$HOME}"
    expanded_path="${expanded_path/\$HOME/$HOME}"

    # 检查该路径是否已在 PATH 中
    if [[ ":$PATH:" == *":$expanded_path:"* ]]; then
        log_info "  Path already in PATH: $expanded_path (skip)"
        return 0
    fi

    # 检查/创建目录
    if [ ! -d "$expanded_path" ]; then
        log_warning "  Path directory does not exist: $expanded_path"
        mkdir -p "$expanded_path" 2>/dev/null || true
    fi

    # 添加到当前 PATH
    export PATH="$expanded_path:$PATH"
    log_info "  Added to PATH: $expanded_path"

    # 写入 .bashrc（带 marker 防重复）
    if [ "$write_bashrc" = "true" ]; then
        local bashrc="$HOME/.bashrc"
        local marker="# AgentBox PATH: $expanded_path"
        if [ -f "$bashrc" ] && ! grep -qF "$marker" "$bashrc"; then
            echo "" >> "$bashrc"
            echo "$marker" >> "$bashrc"
            echo "export PATH=\"$expanded_path:\$PATH\"" >> "$bashrc"
            log_info "  Added to .bashrc: $expanded_path"
        fi
    fi
}

# ===========================================
# 插件环境变量处理
# ===========================================

# 处理插件环境变量
# 格式：
#   VAR_NAME: required     - 检查外部必需变量
#   VAR_NAME: optional     - 外部可选变量（不做检查）
#   VAR_NAME: export ...   - 执行环境设置
#   PATH_APPEND: /path     - 将路径添加到 PATH 和 .bashrc（只添加一次）
# 用法：process_plugin_env <plugin_file> [action]
#   action: all, check, setup
process_plugin_env() {
    local plugin_file="$1"
    local action="${2:-all}"

    if [ ! -f "$plugin_file" ]; then
        return 0
    fi

    # 加载全局 shell 配置（只在 setup 模式下）
    if [ "$action" = "setup" ] || [ "$action" = "all" ]; then
        source "$HOME/.bashrc" 2>/dev/null || true
        source "$HOME/.profile" 2>/dev/null || true
    fi

    # 解析 env 配置
    local env_vars=$(sed -n '/^env:/,/^[a-z]/p' "$plugin_file" | grep -E '^\s+[A-Z_]+:' | sed 's/^\s*//')

    while IFS= read -r line; do
        [ -z "$line" ] && continue

        local var_name=$(echo "$line" | cut -d':' -f1 | xargs)
        local var_value=$(echo "$line" | cut -d':' -f2- | xargs)

        case "$var_name" in
            PATH_APPEND)
                # PATH_APPEND: 简洁格式，添加路径到 PATH 和 .bashrc
                if [ "$action" = "setup" ] || [ "$action" = "all" ]; then
                    # 支持命令替换 $(...) 和变量替换 ${...}
                    local expanded_path="$var_value"
                    if [[ "$var_value" == *'$('* ]] || [[ "$var_value" == *'${'* ]]; then
                        expanded_path=$(eval echo "$var_value" 2>/dev/null) || expanded_path="$var_value"
                    fi
                    _add_to_path "$expanded_path"
                fi
                ;;
            PATH)
                # 旧格式兼容：export PATH="..."
                if [ "$action" = "setup" ] || [ "$action" = "all" ]; then
                    local path_to_add=$(echo "$var_value" | sed -n 's/.*export PATH="\([^:]*\):.*/\1/p')
                    [ -n "$path_to_add" ] && _add_to_path "$path_to_add" false
                fi
                ;;
            *)
                # 其他变量处理
                case "$var_value" in
                    required)
                        if [ "$action" = "check" ] || [ "$action" = "all" ]; then
                            [ -z "${!var_name}" ] && { log_error "Required env not set: $var_name"; return 1; }
                        fi
                        ;;
                    optional)
                        :  # 跳过
                        ;;
                    export\ *)
                        if [ "$action" = "setup" ] || [ "$action" = "all" ]; then
                            log_info "  $var_value"
                            eval "$var_value"
                            export $(echo "$var_value" | awk '{print $2}' | cut -d'=' -f1) 2>/dev/null || true

                            # 写入 .bashrc（带 marker 防重复）
                            local bashrc="$HOME/.bashrc"
                            local export_var=$(echo "$var_value" | awk '{print $2}' | cut -d'=' -f1)
                            local marker="# AgentBox ENV: $export_var"
                            if [ -f "$bashrc" ] && ! grep -qF "$marker" "$bashrc"; then
                                echo "" >> "$bashrc"
                                echo "$marker" >> "$bashrc"
                                echo "$var_value" >> "$bashrc"
                                log_info "  Added to .bashrc: $export_var"
                            fi
                        fi
                        ;;
                    *)
                        if [ -n "$var_value" ] && ([ "$action" = "setup" ] || [ "$action" = "all" ]); then
                            log_info "  export $var_name=\"$var_value\""
                            export "$var_name"="$var_value"
                        fi
                        ;;
                esac
                ;;
        esac
    done <<< "$env_vars"

    return 0
}

# ===========================================
# 镜像源配置函数
# ===========================================

# 配置镜像源
# 用法：configure_mirrors
configure_mirrors() {
    log_info "Configuring mirror sources..."

    # 设置默认的镜像源（如果环境变量未设置）
    : "${NPM_REGISTRY:=https://registry.npmmirror.com}"
    : "${PNPM_REGISTRY:=https://registry.npmmirror.com}"
    : "${PIP_INDEX_URL:=https://mirrors.aliyun.com/pypi/simple/}"
    : "${PIP_TRUSTED_HOST:=mirrors.aliyun.com}"
    : "${GOPROXY:=https://goproxy.cn,direct}"

    # NPM 镜像源配置
    npm config set registry "$NPM_REGISTRY" -g 2>/dev/null || true
    log_success "NPM registry: $NPM_REGISTRY"

    # PNPM 镜像源配置
    if command -v pnpm &> /dev/null; then
        pnpm config set registry "$PNPM_REGISTRY" -g 2>/dev/null || true
        log_success "PNPM registry: $PNPM_REGISTRY"
    fi

    # PIP 镜像源配置
    pip3 config set global.index-url "$PIP_INDEX_URL" 2>/dev/null || true
    pip3 config set global.trusted-host "$PIP_TRUSTED_HOST" 2>/dev/null || true
    log_success "PIP index: $PIP_INDEX_URL"

    # Go 代理配置
    if [ -n "$GOPROXY" ]; then
        go env -w GOPROXY="$GOPROXY" 2>/dev/null || true
        log_success "GOPROXY: $GOPROXY"
    fi

    # GitHub 代理提示
    if [ -n "$GITHUB_PROXY" ]; then
        log_success "GitHub proxy: $GITHUB_PROXY"
        export GITHUB_PROXY
    fi

    # HTTP/HTTPS 代理配置
    if [ -n "$HTTP_PROXY" ]; then
        export HTTP_PROXY
        log_success "HTTP_PROXY: $HTTP_PROXY"
    fi
    if [ -n "$HTTPS_PROXY" ]; then
        export HTTPS_PROXY
        log_success "HTTPS_PROXY: $HTTPS_PROXY"
    fi

    # 安装脚本代理
    if [ -n "$INSTALL_PROXY" ]; then
        export INSTALL_PROXY
        log_success "INSTALL_PROXY: $INSTALL_PROXY"
    fi

    log_success "Mirror sources configured"
}

# 显示当前镜像源配置
# 用法：show_mirror_config
show_mirror_config() {
    echo -e "\n${CYAN}Mirror Sources:${NC}"
    echo "  NPM:    $(npm config get registry 2>/dev/null || echo 'default')"
    if command -v pnpm &> /dev/null; then
        echo "  PNPM:   $(pnpm config get registry 2>/dev/null || echo 'default')"
    fi
    echo "  PIP:    $(pip3 config get global.index-url 2>/dev/null || echo 'default')"
    if [ -n "$GITHUB_PROXY" ]; then
        echo "  GitHub: $GITHUB_PROXY"
    fi
    if [ -n "$GOPROXY" ]; then
        echo "  Go:     $GOPROXY"
    fi

    echo -e "\n${CYAN}Proxy Settings:${NC}"
    if [ -n "$HTTP_PROXY" ]; then
        echo "  HTTP:   $HTTP_PROXY"
    fi
    if [ -n "$HTTPS_PROXY" ]; then
        echo "  HTTPS:  $HTTPS_PROXY"
    fi
    if [ -n "$INSTALL_PROXY" ]; then
        echo "  Install: $INSTALL_PROXY"
    fi
    if [ -z "$HTTP_PROXY" ] && [ -z "$HTTPS_PROXY" ] && [ -z "$INSTALL_PROXY" ]; then
        echo "  (none configured)"
    fi
    echo ""
}

# ===========================================
# 依赖检查函数
# ===========================================

# 检查命令是否存在
check_command() {
    command -v "$1" &> /dev/null
}

# 检查插件依赖
# 用法：check_plugin_dependencies <plugin_file>
check_plugin_dependencies() {
    local plugin_file="$1"
    local deps=$(sed -n '/^requires:/,/^[a-z]/p' "$plugin_file" | grep -E '^\s+-' | sed 's/^\s*- //')

    for dep in $deps; do
        local dep_name=$(echo "$dep" | cut -d' ' -f1)
        local dep_version=$(echo "$dep" | cut -d' ' -f2-)

        case "$dep_name" in
            nodejs)
                if ! check_command node; then
                    log_error "Missing dependency: Node.js"
                    return 1
                fi
                ;;
            npm)
                if ! check_command npm; then
                    log_error "Missing dependency: npm"
                    return 1
                fi
                ;;
            python*)
                if ! check_command python3; then
                    log_error "Missing dependency: Python"
                    return 1
                fi
                ;;
            pip)
                if ! check_command pip3 && ! check_command pip; then
                    log_error "Missing dependency: pip"
                    return 1
                fi
                ;;
            curl)
                if ! check_command curl; then
                    log_error "Missing dependency: curl"
                    return 1
                fi
                ;;
            bash)
                if ! check_command bash; then
                    log_error "Missing dependency: bash"
                    return 1
                fi
                ;;
            docker)
                if ! check_command docker; then
                    log_error "Missing dependency: docker"
                    return 1
                fi
                ;;
            ansible)
                if ! check_command ansible; then
                    log_error "Missing dependency: ansible"
                    return 1
                fi
                ;;
            ansible-playbook)
                if ! check_command ansible-playbook; then
                    log_error "Missing dependency: ansible-playbook"
                    return 1
                fi
                ;;
            make)
                if ! check_command make; then
                    log_error "Missing dependency: make"
                    return 1
                fi
                ;;
            jq)
                if ! check_command jq; then
                    log_error "Missing dependency: jq"
                    return 1
                fi
                ;;
            go)
                if ! check_command go; then
                    log_error "Missing dependency: go"
                    return 1
                fi
                ;;
        esac
    done

    return 0
}

# 检查系统依赖
# 用法：check_dependencies
check_dependencies() {
    log_info "Checking dependencies..."

    local missing_deps=()

    # 检查 Node.js
    if ! check_command node; then
        missing_deps+=("nodejs")
    else
        log_success "Node.js $(node --version) found"
    fi

    # 检查 Python
    if ! check_command python3; then
        missing_deps+=("python3")
    else
        log_success "Python $(python3 --version) found"
    fi

    # 检查 npm
    if ! check_command npm; then
        missing_deps+=("npm")
    else
        log_success "npm $(npm --version) found"
    fi

    # 检查 pnpm
    if check_command pnpm; then
        log_success "pnpm $(pnpm --version) found"
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        return 1
    fi

    return 0
}

# ===========================================
# Docker-in-Docker 挂载继承函数
# ===========================================

# 获取 agentbox 容器中所有指定路径相关的挂载信息
# 用法：get_inherited_mounts <container_name> <path_prefix>
#   container_name: 容器名称（默认 agentbox）
#   path_prefix: 挂载路径前缀（默认 /host-share）
# 返回：VOLUME_ARGS 变量，包含所有 -v 参数
# 示例：
#   get_inherited_mounts agentbox /host-share
#   echo "$VOLUME_ARGS"  # 输出: -v "/home/user/workspace:/host-share/workspace" -v "/path/to/host-share:/host-share"
get_inherited_mounts() {
    local container_name="${1:-agentbox}"
    local path_prefix="${2:-/host-share}"

    VOLUME_ARGS=""
    HOST_SHARE_MOUNTS=""

    # 清理可能存在的临时文件
    rm -f /tmp/volume_args_$$ /tmp/host_share_mounts_$$ 2>/dev/null

    # 获取容器所有挂载信息 - 使用 JSON 格式更可靠
    local mounts_json=$(docker inspect "$container_name" --format '{{json .Mounts}}' 2>/dev/null)

    if [ -z "$mounts_json" ]; then
        log_warning "无法获取容器 $container_name 的挂载信息"
        return 1
    fi

    # 使用进程替换避免子进程变量丢失问题
    # jq 和非 jq 方案都使用临时文件来传递结果
    if command -v jq &> /dev/null; then
        # 使用 jq 解析 JSON
        while IFS= read -r mount_entry; do
            [ -z "$mount_entry" ] && continue

            local source=$(echo "$mount_entry" | jq -r '.Source')
            local dest=$(echo "$mount_entry" | jq -r '.Destination')

            # 检查是否匹配路径前缀（精确匹配或子目录）
            if [ "$dest" = "$path_prefix" ] || [[ "$dest" == "${path_prefix}/"* ]]; then
                # 将路径转换为 Docker 兼容格式
                if [[ "$source" =~ ^/host_mnt/ || "$source" =~ ^/run/desktop/mnt/host/ ]]; then
                    log_info "使用 Docker Desktop Linux VM 格式路径: $source"
                elif [[ "$source" =~ ^[A-Za-z]: ]]; then
                    source=$(echo "$source" | sed 's|\\|/|g' | sed 's|^\([A-Za-z]\):|/\L\1|')
                    log_info "转换 Windows 路径为 Linux 格式: $source"
                fi

                # 添加引号保护路径，写入临时文件
                echo "-v \"${source}:${dest}\"" >> /tmp/volume_args_$$
                echo "${source}:${dest}" >> /tmp/host_share_mounts_$$
                log_info "继承挂载: ${source} -> ${dest}"
            fi
        done < <(echo "$mounts_json" | jq -c '.[]')
    else
        # 回退方案：使用 Go 模板直接输出，使用 | 作为分隔符避免冒号分割问题
        while IFS='|' read -r source dest; do
            [ -z "$source" ] && continue

            # 检查是否匹配路径前缀
            if [ "$dest" = "$path_prefix" ] || [[ "$dest" == "${path_prefix}/"* ]]; then
                # 将路径转换为 Docker 兼容格式
                if [[ "$source" =~ ^/host_mnt/ || "$source" =~ ^/run/desktop/mnt/host/ ]]; then
                    log_info "使用 Docker Desktop Linux VM 格式路径: $source"
                elif [[ "$source" =~ ^[A-Za-z]: ]]; then
                    source=$(echo "$source" | sed 's|\\|/|g' | sed 's|^\([A-Za-z]\):|/\L\1|')
                    log_info "转换 Windows 路径为 Linux 格式: $source"
                fi

                # 添加引号保护路径，写入临时文件
                echo "-v \"${source}:${dest}\"" >> /tmp/volume_args_$$
                echo "${source}:${dest}" >> /tmp/host_share_mounts_$$
                log_info "继承挂载: ${source} -> ${dest}"
            fi
        done < <(docker inspect "$container_name" --format '{{range .Mounts}}{{.Source}}|{{.Destination}}{{println}}{{end}}' 2>/dev/null)
    fi

    # 从临时文件读取结果
    if [ -f /tmp/volume_args_$$ ]; then
        VOLUME_ARGS=$(cat /tmp/volume_args_$$ | tr '\n' ' ')
        rm -f /tmp/volume_args_$$
    fi
    if [ -f /tmp/host_share_mounts_$$ ]; then
        HOST_SHARE_MOUNTS=$(cat /tmp/host_share_mounts_$$ | tr '\n' ' ')
        rm -f /tmp/host_share_mounts_$$
    fi

    if [ -z "$VOLUME_ARGS" ]; then
        log_warning "未找到任何 ${path_prefix} 相关挂载"
        return 1
    fi

    return 0
}

# 获取单个挂载的源路径（简化版）
# 用法：get_mount_source <container_name> <dest_path>
#   container_name: 容器名称（默认 agentbox）
#   dest_path: 容器内目标路径
# 返回：源路径（已转换为 Docker 兼容格式）
get_mount_source() {
    local container_name="${1:-agentbox}"
    local dest_path="$2"

    local source=$(docker inspect "$container_name" --format '{{range .Mounts}}{{if eq .Destination "'"$dest_path"'"}}{{.Source}}{{end}}{{end}}' 2>/dev/null)

    if [ -z "$source" ]; then
        log_warning "无法获取 $dest_path 挂载源"
        return 1
    fi

    # 将路径转换为 Docker 兼容格式
    if [[ "$source" =~ ^/host_mnt/ || "$source" =~ ^/run/desktop/mnt/host/ ]]; then
        :  # Docker Desktop Linux VM 格式，直接使用
    elif [[ "$source" =~ ^[A-Za-z]: ]]; then
        source=$(echo "$source" | tr "\\" "/" | sed "s|^\([A-Za-z]\):|/\L\1|")
    else
        source=$(echo "$source" | tr -s "/")
    fi

    echo "$source"
    return 0
}

# ===========================================
# Docker-in-Docker 路径映射
# ===========================================

# 获取容器挂载点对应的主机路径
# 用法：get_host_mount_path [container_name] [container_path] [relative_path]
# 参数：
#   container_name - 容器名称（默认：agentbox）
#   container_path - 容器内挂载路径（默认：/home/agent）
#   relative_path  - 相对于 container_path 的子路径（可选）
# 返回：转换后的主机路径（stdout），失败返回容器路径
#
# 支持的平台：
#   - Linux 原生 Docker：返回原始主机路径
#   - Docker Desktop WSL2 (Windows)：转换 D:\path 为 /d/path 格式
#   - Docker Desktop macOS：处理 /host_mnt 或 /run/desktop/mnt/host 格式
get_host_mount_path() {
    local container_name="${1:-agentbox}"
    local container_path="${2:-/home/agent}"
    local relative_path="${3:-}"

    # 获取挂载源路径（主机路径）
    local host_source=$(docker inspect "$container_name" --format '{{range .Mounts}}{{if eq .Destination "'"$container_path"'"}}{{.Source}}{{end}}{{end}}' 2>/dev/null)

    if [ -z "$host_source" ]; then
        # 无法获取挂载源，返回容器路径（fallback）
        if [ -n "$relative_path" ]; then
            echo "${container_path}/${relative_path}"
        else
            echo "$container_path"
        fi
        return 1
    fi

    # 转换路径为 Unix 格式
    if [[ "$host_source" =~ ^/host_mnt/ || "$host_source" =~ ^/run/desktop/mnt/host/ ]]; then
        # Docker Desktop macOS/Linux VM 格式，保持原样
        :
    elif [[ "$host_source" =~ ^[A-Za-z]: ]]; then
        # Windows 路径 D:\path -> /d/path 格式
        host_source=$(echo "$host_source" | tr '\\' '/' | sed 's|^\([A-Za-z]\):|/\L\1|')
    else
        # 标准 Linux 路径
        host_source=$(echo "$host_source" | tr -s '/')
    fi

    # 如果指定了相对路径，追加到结果
    if [ -n "$relative_path" ]; then
        echo "${host_source}/${relative_path}"
    else
        echo "$host_source"
    fi

    return 0
}

# 创建主机路径到容器路径的符号链接
# 用法：create_host_path_mapping [container_name] [container_path]
# 功能：让 Docker-in-Docker 插件能够使用主机路径访问容器内的文件
# 例如：/home/user/project/data -> /home/agent
#
# 注意：此函数处理特殊情况 - 当主机路径的最后一部分（如 "data")
# 已经作为挂载点存在时，需要先移除挂载点（但这会破坏挂载），所以
# 我们采用另一种策略：创建父目录结构，然后让用户通过父目录访问
create_host_path_mapping() {
    local container_name="${1:-agentbox}"
    local container_path="${2:-/home/agent}"

    # 使用共享函数获取主机路径
    local host_source=$(get_host_mount_path "$container_name" "$container_path")

    # 检查是否成功获取（get_host_mount_path 失败时会返回容器路径）
    if [ "$host_source" = "$container_path" ]; then
        log_warning "无法获取 $container_path 挂载源，跳过路径映射"
        return 1
    fi

    log_info "主机路径: $host_source -> 容器路径: $container_path"

    # 特殊情况处理：
    # host_source (如 /home/lunnlew/my-workspace/agent-box/data) 已经作为挂载点存在
    # 我们需要创建父目录结构，并让最后一部分指向容器路径
    #
    # 策略：创建 host_source 的父目录，然后在父目录中创建指向 container_path 的链接
    # 例如：创建 /home/lunnlew/my-workspace/agent-box 目录，然后在其中创建 data -> /home/agent 链接

    local link_name=$(basename "$host_source")
    local link_parent=$(dirname "$host_source")

    # 检查父目录是否已存在
    if [ -d "$link_parent" ]; then
        log_info "父目录已存在: $link_parent"
    else
        # 创建父目录结构
        log_info "创建路径映射目录结构: $link_parent"

        if [ "$(id -u)" = "0" ]; then
            mkdir -p "$link_parent" 2>/dev/null || {
                log_warning "无法创建父目录: $link_parent"
                return 1
            }
        else
            mkdir -p "$link_parent" 2>/dev/null || {
                log_warning "无法创建父目录: $link_parent"
                log_warning "请在容器启动时以 root 用户运行"
                return 1
            }
        fi
    fi

    # 检查 link_name 是否已存在
    local full_link_path="${link_parent}/${link_name}"

    if [ -L "$full_link_path" ]; then
        local current_link=$(readlink "$full_link_path" 2>/dev/null)
        if [ "$current_link" = "$container_path" ]; then
            log_info "路径映射已存在: $full_link_path -> $container_path"
            return 0
        fi
        log_info "更新路径映射: $full_link_path -> $container_path"
        rm -f "$full_link_path" 2>/dev/null || {
            log_warning "无法移除旧链接: $full_link_path"
            return 1
        }
    elif [ -d "$full_link_path" ]; then
        # 这是一个真实目录，可能是挂载点本身
        # 我们不能删除它，因为这会破坏挂载
        # 检查它是否就是挂载点（即内容与 container_path 相同）
        if [ "$(cd "$full_link_path" 2>/dev/null && pwd)" = "$(cd "$container_path" 2>/dev/null && pwd)" ]; then
            log_info "路径已是挂载点，无需创建链接: $full_link_path"
            # 但父目录结构已创建，这对于访问子路径有用
            return 0
        fi
        log_warning "路径已存在且为真实目录: $full_link_path"
        log_warning "无法创建符号链接（可能是其他挂载点）"
        return 1
    elif [ -e "$full_link_path" ]; then
        log_warning "路径已存在且为文件: $full_link_path"
        return 1
    fi

    # 创建符号链接
    ln -sf "$container_path" "$full_link_path" 2>/dev/null || {
        log_warning "无法创建路径映射: $full_link_path -> $container_path"
        return 1
    }

    log_success "路径映射创建成功: $full_link_path -> $container_path"
    return 0
}

# ===========================================
# 网络稳定性工具
# ===========================================

# 带重试的命令执行
# 用法：retry_command <command> [max_retries] [delay_seconds]
# 例如：retry_command "npm install -g openclaw" 3 10
retry_command() {
    local cmd="$1"
    local max_retries="${2:-3}"
    local delay="${3:-5}"
    local retry_on_error="${4:-}"  # 可选：指定要重试的错误模式

    for i in $(seq 1 $max_retries); do
        log_info "Attempt $i/$max_retries: $cmd"

        local output
        local exit_code
        output=$(eval "$cmd" 2>&1) && exit_code=0 || exit_code=$?

        if [ $exit_code -eq 0 ]; then
            log_success "Command succeeded on attempt $i"
            return 0
        fi

        # 检查是否是可重试的错误（网络相关）
        local is_retryable=false
        if echo "$output" | grep -qiE "network|timeout|connection|ECONNREFUSED|ENOTFOUND|ETIMEDOUT|socket hang up|getaddrinfo|DNS"; then
            is_retryable=true
        fi
        if [ -n "$retry_on_error" ] && echo "$output" | grep -qiE "$retry_on_error"; then
            is_retryable=true
        fi

        if [ "$is_retryable" = true ] && [ $i -lt $max_retries ]; then
            log_warning "Network error detected, retrying in ${delay}s..."
            log_warning "Error: $(echo "$output" | tail -3)"
            sleep $delay
        elif [ $i -lt $max_retries ]; then
            log_warning "Attempt $i failed, retrying in ${delay}s..."
            sleep $delay
        fi
    done

    log_error "All $max_retries attempts failed"
    log_error "Last error: $(echo "$output" | tail -5)"
    return 1
}

# 检查并使用本地 npm registry（如果可用）
# 用法：get_npm_registry
# 返回：优先使用本地 registry，否则使用配置的远程 registry
get_npm_registry() {
    # 检查本地 verdaccio 是否运行
    if command -v curl &> /dev/null && curl -fsSL "http://localhost:4873" >/dev/null 2>&1; then
        echo "http://localhost:4873"
        return 0
    fi

    # 使用配置的远程 registry
    echo "${NPM_REGISTRY:-https://registry.npmmirror.com}"
}

# 检查并使用本地 pip index（如果可用）
# 用法：get_pip_index_url
get_pip_index_url() {
    # 检查本地 pypiserver 是否运行
    if command -v curl &> /dev/null && curl -fsSL "http://localhost:8080/simple" >/dev/null 2>&1; then
        echo "http://localhost:8080/simple"
        return 0
    fi

    echo "${PIP_INDEX_URL:-https://mirrors.aliyun.com/pypi/simple/}"
}

# ===========================================
# 高级网络函数
# ===========================================

# 通用 HTTP 请求（支持代理、重试）
# 用法：http_request <method> <url> [output_file] [extra_curl_opts]
http_request() {
    local method="${1:-GET}"
    local url="$2"
    local output="$3"
    local extra_opts="${4:-}"

    local proxy="${HTTP_PROXY:-${HTTPS_PROXY:-}}"
    local opts="-X $method -fsSL --connect-timeout 30 --max-time ${NETWORK_TIMEOUT:-120}"
    opts="$opts --retry ${NETWORK_RETRY_COUNT:-3} --retry-delay ${NETWORK_RETRY_DELAY:-10}"

    if [ -n "$proxy" ]; then
        opts="$opts --proxy $proxy"
    fi

    if [ -n "$output" ]; then
        opts="$opts -o $output"
    fi

    opts="$opts $extra_opts"

    log_info "HTTP $method: $url"
    curl $opts "$url"
}

# 智能下载文件（支持 GitHub 代理）
# 用法：net_download <url> <output_path> [options]
# 选项：--no-proxy, --no-retry, --github
net_download() {
    local url="$1"
    local output="$2"
    shift 2
    local use_proxy=true
    local use_retry=true
    local force_github=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-proxy) use_proxy=false ;;
            --no-retry) use_retry=false ;;
            --github) force_github=true ;;
        esac
        shift
    done

    local download_url="$url"
    if { [[ "$url" =~ github.com ]] || [ "$force_github" = true ]; } && [ -n "$GITHUB_PROXY" ]; then
        download_url="${GITHUB_PROXY}${url}"
        log_info "Using GitHub proxy: $GITHUB_PROXY"
    fi

    local proxy_opts=""
    [ "$use_proxy" = true ] && [ -n "$HTTP_PROXY" ] && proxy_opts="--proxy $HTTP_PROXY"

    local retry_opts=""
    [ "$use_retry" = true ] && retry_opts="--retry ${NETWORK_RETRY_COUNT:-3} --retry-delay ${NETWORK_RETRY_DELAY:-10}"

    local cmd="curl -fsSL --connect-timeout 30 --max-time ${NETWORK_TIMEOUT:-120} $retry_opts $proxy_opts '$download_url' -o '$output'"

    mkdir -p "$(dirname "$output")" 2>/dev/null

    if [ "$use_retry" = true ]; then
        retry_command "$cmd"
    else
        eval "$cmd"
    fi
}

# npm 安装封装
# 用法：net_npm_install <package> [--global|-g] [--save-dev] [--save] [--no-save]
# 默认全局安装
net_npm_install() {
    local pkg=""
    local global=true  # 默认全局安装
    local save_flag=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --global|-g) global=true ;;
            --local) global=false ;;  # 新增：明确指定本地安装
            --save-dev) save_flag="--save-dev" ;;
            --save) save_flag="--save" ;;
            --no-save) save_flag="--no-save" ;;
            *) pkg="$1" ;;
        esac
        shift
    done

    [ -z "$pkg" ] && { log_error "Package name required"; return 1; }

    local registry=$(get_npm_registry)
    local global_flag=""
    [ "$global" = true ] && global_flag="-g"

    local cmd="npm install $global_flag --registry '$registry' --maxsockets 1 $save_flag '$pkg'"
    log_info "npm install: $pkg (registry: $registry)"
    retry_command "$cmd"
}

# pnpm 安装封装
net_pnpm_install() {
    local pkg=""
    local global=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --global|-g) global=true ;;
            *) pkg="$1" ;;
        esac
        shift
    done

    [ -z "$pkg" ] && { log_error "Package name required"; return 1; }

    local registry="${PNPM_REGISTRY:-https://registry.npmmirror.com}"
    local global_flag=""
    [ "$global" = true ] && global_flag="-g"

    local cmd="pnpm install $global_flag --registry '$registry' '$pkg'"
    log_info "pnpm install: $pkg (registry: $registry)"
    retry_command "$cmd"
}

# pip 安装封装
# 用法：net_pip_install <package> [--no-user] [--break-system-packages]
net_pip_install() {
    local pkg=""
    local user="--user"
    local extra_args=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-user) user="" ;;
            --break-system-packages) extra_args="$extra_args --break-system-packages" ;;
            *) pkg="$1" ;;
        esac
        shift
    done

    [ -z "$pkg" ] && { log_error "Package name required"; return 1; }

    local index_url=$(get_pip_index_url)
    local trusted_host="${PIP_TRUSTED_HOST:-mirrors.aliyun.com}"

    local cmd="pip3 install $user --index-url '$index_url' --trusted-host '$trusted_host' $extra_args '$pkg'"
    log_info "pip install: $pkg (index: $index_url)"
    retry_command "$cmd"
}

# go 安装封装
net_go_install() {
    local pkg="$1"
    [ -z "$pkg" ] && { log_error "Package name required"; return 1; }

    local proxy="${GOPROXY:-https://goproxy.cn,direct}"
    log_info "go install: $pkg (proxy: $proxy)"
    GOPROXY="$proxy" go install "$pkg"
}

# GitHub release 下载
# 用法：net_github_release <owner/repo> <tag> <file_pattern> <output_dir>
net_github_release() {
    local repo="$1"
    local tag="$2"
    local pattern="$3"
    local output_dir="${4:-/tmp}"

    local api_url="https://api.github.com/repos/$repo/releases/tags/$tag"
    [ "$tag" = "latest" ] && api_url="https://api.github.com/repos/$repo/releases/latest"

    log_info "Fetching GitHub release: $repo@$tag"

    local release_info
    if [ -n "$GITHUB_PROXY" ]; then
        release_info=$(curl -fsSL "${GITHUB_PROXY}${api_url}")
    else
        release_info=$(curl -fsSL "$api_url")
    fi

    [ -z "$release_info" ] && { log_error "Failed to fetch release info"; return 1; }

    local download_url=$(echo "$release_info" | grep -o "\"browser_download_url\": \"[^\"]*" | grep "$pattern" | head -1 | sed 's/"browser_download_url": "//')

    [ -z "$download_url" ] && { log_error "No matching file found for pattern: $pattern"; return 1; }

    local filename=$(basename "$download_url")
    local output_path="$output_dir/$filename"

    log_info "Downloading: $filename"
    net_download "$download_url" "$output_path" --github

    echo "$output_path"
}

# GitHub 仓库克隆
# 用法：net_git_clone <repo_url> <target_dir> [--depth 1]
net_git_clone() {
    local url="$1"
    local target="$2"
    shift 2
    local depth=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --depth) depth="--depth $2"; shift ;;
        esac
        shift
    done

    local clone_url="$url"
    if [[ "$url" =~ github.com ]] && [ -n "$GITHUB_PROXY" ]; then
        clone_url="${GITHUB_PROXY}${url}"
        log_info "Using GitHub proxy for clone"
    fi

    log_info "git clone: $url"
    git clone $depth "$clone_url" "$target"
}

# 网络连接检查
net_check_connection() {
    local test_urls=("https://registry.npmmirror.com" "https://mirrors.aliyun.com" "https://github.com")

    log_info "Checking network connectivity..."

    for url in "${test_urls[@]}"; do
        if curl -fsSL --connect-timeout 5 "$url" >/dev/null 2>&1; then
            log_success "Connected: $url"
        else
            log_warning "Failed: $url"
        fi
    done
}

# 显示网络配置
net_show_config() {
    echo -e "\n${CYAN}Network Configuration:${NC}"
    echo "  NPM Registry:  $(get_npm_registry)"
    echo "  PIP Index:     $(get_pip_index_url)"
    echo "  Go Proxy:      ${GOPROXY:-default}"
    [ -n "$GITHUB_PROXY" ] && echo "  GitHub Proxy:  $GITHUB_PROXY"
    [ -n "$HTTP_PROXY" ] && echo "  HTTP Proxy:    $HTTP_PROXY"
    [ -n "$HTTPS_PROXY" ] && echo "  HTTPS Proxy:   $HTTPS_PROXY"
    echo ""
}

# ===========================================
# Ansible 依赖支持
# ===========================================

# 检查 ansible 依赖
check_ansible() {
    if ! check_command ansible; then
        log_error "Missing dependency: ansible"
        return 1
    fi
    if ! check_command ansible-playbook; then
        log_error "Missing dependency: ansible-playbook"
        return 1
    fi
    log_success "Ansible $(ansible --version | head -1) found"
    return 0
}

# 运行 ansible playbook（带重试）
# 用法：net_ansible_playbook <playbook_path> [extra_vars]
net_ansible_playbook() {
    local playbook="$1"
    local extra_vars="${2:-}"

    local cmd="ansible-playbook '$playbook'"
    if [ -n "$extra_vars" ]; then
        cmd="$cmd -e '$extra_vars'"
    fi

    log_info "Running ansible playbook: $playbook"
    retry_command "$cmd" 2 10
}
