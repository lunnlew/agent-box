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
