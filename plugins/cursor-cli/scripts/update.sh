#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

log_info "Updating Cursor CLI..."

# 备份用户配置
if [ -d ~/.cursor ]; then
  log_info "Backing up configuration..."
  cp -r ~/.cursor ~/.cursor.bak.$(date +%Y%m%d%H%M%S) 2>/dev/null || true
fi

# 执行安装脚本（会覆盖旧版本）
log_info "Running install script..."
if [ -n "$INSTALL_PROXY" ]; then
  curl -fsSL --proxy "$INSTALL_PROXY" https://cursor.com/install | bash
elif [ -n "$HTTPS_PROXY" ]; then
  curl -fsSL --proxy "$HTTPS_PROXY" https://cursor.com/install | bash
else
  curl -fsSL https://cursor.com/install | bash
fi

# 验证更新
log_info "Verifying update..."
if command -v agent &>/dev/null; then
  agent --version
  log_success "Cursor CLI updated successfully"
else
  log_error "Update verification failed"
  # 恢复备份
  if [ -d ~/.cursor.bak.* ]; then
    mv ~/.cursor.bak.* ~/.cursor 2>/dev/null || true
  fi
  exit 1
fi

# 清理备份
rm -rf ~/.cursor.bak.* 2>/dev/null || true