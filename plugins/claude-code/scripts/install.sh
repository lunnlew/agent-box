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

# 执行安装脚本（支持代理）
log_info "Downloading and running install script..."
if [ -n "$INSTALL_PROXY" ]; then
  curl -fsSL --proxy "$INSTALL_PROXY" https://claude.ai/install.sh | bash
elif [ -n "$HTTPS_PROXY" ]; then
  curl -fsSL --proxy "$HTTPS_PROXY" https://claude.ai/install.sh | bash
else
  curl -fsSL https://claude.ai/install.sh | bash
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