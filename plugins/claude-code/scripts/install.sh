#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

log_info "Installing Claude Code..."

# 清理旧版本
if [ -f ~/.local/bin/claude ]; then
  log_info "Found existing installation, removing..."
  rm -f ~/.local/bin/claude 2>/dev/null || true
fi

# 执行安装脚本（使用智能下载）
log_info "Downloading and running install script..."
if type net_download &>/dev/null; then
  # 使用智能下载获取安装脚本
  net_download "https://claude.ai/install.sh" "/tmp/claude-install.sh" --no-retry
  bash /tmp/claude-install.sh
else
  # 回退到原有逻辑
  if [ -n "$INSTALL_PROXY" ]; then
    curl -fsSL --proxy "$INSTALL_PROXY" https://claude.ai/install.sh | bash
  elif [ -n "$HTTPS_PROXY" ]; then
    curl -fsSL --proxy "$HTTPS_PROXY" https://claude.ai/install.sh | bash
  else
    curl -fsSL https://claude.ai/install.sh | bash
  fi
fi

# 验证安装
log_info "Verifying installation..."
if [ ! -f ~/.local/bin/claude ] && ! command -v claude &>/dev/null; then
  log_error "Installation failed: claude binary not found"
  exit 1
fi

# 创建配置（跳过 onboarding）
log_info "Configuring Claude Code..."
mkdir -p ~/.claude
echo '{"hasCompletedOnboarding": true}' > ~/.claude.json

# 修复权限
chown agent:agent ~/.claude.json 2>/dev/null || true
chown -R agent:agent ~/.claude 2>/dev/null || true

claude --version
log_success "Claude Code installed successfully"

echo "alias claude='IS_SANDBOX=1 claude'" >> ~/.bashrc