#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# OpenClaw Gateway 启动脚本

OPENCLAW_PORT="${OPENCLAW_PORT:-18789}"

# 确保配置文件存在并设置 gateway.mode=local
mkdir -p ~/.openclaw
if [ ! -f ~/.openclaw/openclaw.json ]; then
    log_info "Creating OpenClaw configuration..."
    # 使用 --dev 创建开发配置
    openclaw gateway --dev --port ${OPENCLAW_PORT} 2>/dev/null || true
fi

# 检查 gateway.mode 是否已设置
if ! grep -q '"gateway"' ~/.openclaw/openclaw.json 2>/dev/null || \
   ! grep -q '"mode"' ~/.openclaw/openclaw.json 2>/dev/null; then
    log_info "Setting gateway.mode=local..."
    # 使用 openclaw config set 命令设置
    openclaw config set gateway.mode local 2>/dev/null || {
        # 如果命令失败，直接修改 JSON 文件
        CONFIG_FILE="$HOME/.openclaw/openclaw.json"
        if [ -f "$CONFIG_FILE" ]; then
            # 添加 gateway 配置（使用临时文件避免并发问题）
            TMP_FILE=$(mktemp)
            python3 -c "
import json
try:
    with open('$CONFIG_FILE', 'r') as f:
        config = json.load(f)
    if 'gateway' not in config:
        config['gateway'] = {}
    config['gateway']['mode'] = 'local'
    with open('$TMP_FILE', 'w') as f:
        json.dump(config, f, indent=2)
    print('OK')
except Exception as e:
    print(f'Error: {e}')
" 2>/dev/null && mv "$TMP_FILE" "$CONFIG_FILE" 2>/dev/null || rm -f "$TMP_FILE" 2>/dev/null
        fi
    }
fi

openclaw gateway --port ${OPENCLAW_PORT} --bind lan