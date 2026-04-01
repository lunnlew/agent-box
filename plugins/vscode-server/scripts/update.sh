#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

log_info "Updating VS Code Server..."

# 停止当前服务
pkill -f "code-server" 2>/dev/null || true

# 备份用户配置
if [ -d ~/.config/code-server ]; then
  cp -r ~/.config/code-server ~/.config/code-server.bak.$(date +%Y%m%d%H%M%S) 2>/dev/null || true
fi

# 清理旧版本
log_info "Cleaning up old installation..."
rm -rf ~/.code-server/lib/code-server-* 2>/dev/null || true
rm -rf ~/.cache/code-server 2>/dev/null || true
rm -f ~/.code-server/bin/code-server 2>/dev/null || true

# 执行安装脚本（覆盖安装）
if [ -n "$INSTALL_PROXY" ]; then
  curl -fsSLk --proxy "$INSTALL_PROXY" https://code-server.dev/install.sh | sh -s -- --method standalone
elif [ -n "$HTTPS_PROXY" ]; then
  curl -fsSLk --proxy "$HTTPS_PROXY" https://code-server.dev/install.sh | sh -s -- --method standalone
else
  curl -fsSLk https://code-server.dev/install.sh | sh -s -- --method standalone
fi

# 验证更新
latest_version=$(ls -d ~/.code-server/lib/code-server-* 2>/dev/null | head -1)
if [ -n "$latest_version" ] && [ -f "$latest_version/bin/code-server" ]; then
    ln -sf "$latest_version/bin/code-server" ~/.code-server/bin/code-server
fi

if [ -f ~/.code-server/bin/code-server ] || command -v code-server &>/dev/null; then
  ~/.code-server/bin/code-server --version 2>/dev/null || code-server --version
  log_success "VS Code Server updated successfully"
else
  log_error "Update verification failed"
  if [ -d ~/.config/code-server.bak.* ]; then
    mv ~/.config/code-server.bak.* ~/.config/code-server 2>/dev/null || true
  fi
  exit 1
fi

# 清理备份
rm -rf ~/.config/code-server.bak.* 2>/dev/null || true