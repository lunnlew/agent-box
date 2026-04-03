#!/bin/bash
# ClawPanel 安装脚本
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  # 如果不在容器内，定义简化版日志函数
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

log_info "Installing ClawPanel..."

CLAWPANEL_PATH="$HOME/tools/clawpanel"

# 检查是否已安装
if [ -d "$CLAWPANEL_PATH/dist" ] && [ -f "$CLAWPANEL_PATH/package.json" ]; then
  log_info "ClawPanel already installed, skipping..."
else
  # 清理旧目录
  rm -rf "$CLAWPANEL_PATH" 2>/dev/null || true
  mkdir -p "$CLAWPANEL_PATH"

  # 克隆源码
  log_info "Cloning ClawPanel repository..."
  git clone --depth 1 https://github.com/qingchencloud/clawpanel.git "$CLAWPANEL_PATH"

  # 安装依赖（需要 devDependencies 中的 vite 进行构建）
  log_info "Installing dependencies..."
  cd "$CLAWPANEL_PATH"
  npm install

  # 构建
  log_info "Building ClawPanel..."
  npm run build

  log_success "ClawPanel installed successfully"
fi