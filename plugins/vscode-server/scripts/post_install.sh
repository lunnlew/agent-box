#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}


VSCODE_PORT="${VSCODE_PORT:-8080}"

log_info "Configuring VS Code Server..."
mkdir -p ~/.config/code-server

# 创建配置文件（如果不存在）
if [ ! -f ~/.config/code-server/config.yaml ]; then
  cat > ~/.config/code-server/config.yaml << EOF
bind-addr: 0.0.0.0:${VSCODE_PORT}
auth: password
password: agentbox
cert: false
disable-telemetry: true
EOF
fi

# 安装中文语言包
log_info "Installing Chinese language pack..."
code-server --install-extension MS-CEINTL.vscode-language-pack-zh-hans || true

# 设置默认语言
mkdir -p ~/.local/share/code-server/User
cat > ~/.local/share/code-server/User/argv.json << 'EOF'
{
  "locale": "zh-cn"
}
EOF

echo ""
echo "============================================"
echo "  VS Code Server 安装完成!"
echo "============================================"
echo ""
echo "访问地址：http://localhost:${VSCODE_PORT}"
echo "默认密码：agentbox"
echo "配置目录：~/.config/code-server"
echo "工作目录：\$HOME"
echo "============================================"
echo ""