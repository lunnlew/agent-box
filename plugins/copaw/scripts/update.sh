#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# CoPaw 更新脚本


# 清理 uv 缓存，避免权限问题
log_info "Cleaning uv cache..."
rm -rf ~/.cache/uv 2>/dev/null || true
mkdir -p ~/.cache/uv

log_info "Updating CoPaw..."

# CoPaw 安装脚本会处理更新，无需备份
# 用户数据在 ~/.copaw 目录下，不会被影响

# 执行安装脚本
if [ -n "$INSTALL_PROXY" ]; then
  curl -fsSL --proxy "$INSTALL_PROXY" https://copaw.agentscope.io/install.sh | bash
elif [ -n "$HTTPS_PROXY" ]; then
  curl -fsSL --proxy "$HTTPS_PROXY" https://copaw.agentscope.io/install.sh | bash
else
  curl -fsSL https://copaw.agentscope.io/install.sh | bash
fi

# 验证更新
if command -v copaw &>/dev/null; then
  copaw -h >/dev/null 2>&1 && {
    log_success "CoPaw updated successfully"
  } || {
    log_error "Update verification failed"
    exit 1
  }
else
  log_error "Update failed: copaw command not found"
  exit 1
fi