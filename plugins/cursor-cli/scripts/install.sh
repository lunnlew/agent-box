#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

log_info "Installing Cursor CLI..."

# 清理旧版本
log_info "Checking for existing installation..."
if [ -f ~/.local/bin/agent ]; then
  log_info "Found existing installation, removing..."
  rm -f ~/.local/bin/agent 2>/dev/null || true
fi
if [ -d ~/.cursor ]; then
  log_info "Backing up old config (keeping user data)..."
  mv ~/.cursor ~/.cursor.bak.$(date +%Y%m%d%H%M%S) 2>/dev/null || true
fi

# 执行安装脚本（使用智能下载）
log_info "Downloading and running install script..."
if type net_download &>/dev/null; then
  net_download "https://cursor.com/install" "/tmp/cursor-install.sh" --no-retry
  bash /tmp/cursor-install.sh
else
  # 回退到原有逻辑
  if [ -n "$INSTALL_PROXY" ]; then
    curl -fsSL --proxy "$INSTALL_PROXY" https://cursor.com/install | bash
  elif [ -n "$HTTPS_PROXY" ]; then
    curl -fsSL --proxy "$HTTPS_PROXY" https://cursor.com/install | bash
  else
    curl -fsSL https://cursor.com/install | bash
  fi
fi

# 验证安装
log_info "Verifying installation..."
if [ ! -f ~/.local/bin/agent ] && ! command -v agent &>/dev/null; then
  log_error "Installation failed: agent binary not found"
  # 恢复备份
  if [ -d ~/.cursor.bak.* ]; then
    mv ~/.cursor.bak.* ~/.cursor 2>/dev/null || true
  fi
  exit 1
fi

# 恢复用户配置
if [ -d ~/.cursor.bak.* ]; then
  log_info "Restoring user configuration..."
  cp -r ~/.cursor.bak.*/ ~/.cursor/ 2>/dev/null || true
  rm -rf ~/.cursor.bak.* 2>/dev/null || true
fi

log_success "Cursor CLI installed successfully"