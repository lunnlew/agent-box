#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
}

log_info "Uninstalling VS Code Server..."

# 停止进程
pkill -f "code-server" 2>/dev/null || true

# 移除二进制文件
rm -f ~/.code-server/bin/code-server 2>/dev/null || true
rm -f ~/.local/bin/code-server 2>/dev/null || true

# 移除安装目录
rm -rf ~/.code-server 2>/dev/null || true

rm -rf ~/supervisor/vscode-server.conf 2>/dev/null || true
rm -rf ~/supervisor/vscode-server.sh 2>/dev/null || true

log_success "VS Code Server uninstalled"