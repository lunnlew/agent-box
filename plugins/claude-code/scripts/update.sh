#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

log_info "Updating Claude Code..."

# 执行安装脚本（会覆盖旧版本）
if [ -n "$INSTALL_PROXY" ]; then
  curl -fsSL --proxy "$INSTALL_PROXY" https://claude.ai/install.sh | bash
elif [ -n "$HTTPS_PROXY" ]; then
  curl -fsSL --proxy "$HTTPS_PROXY" https://claude.ai/install.sh | bash
else
  curl -fsSL https://claude.ai/install.sh | bash
fi

# 验证更新
if command -v claude &>/dev/null; then
  claude --version
  log_success "Claude Code updated successfully"
else
  log_error "Update verification failed"
  exit 1
fi