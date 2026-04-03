#!/bin/bash
# ClawPanel 更新脚本
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

log_info "Updating ClawPanel..."

# 停止当前服务
pkill -f "clawpanel" 2>/dev/null || true
pkill -f "node.*serve" 2>/dev/null || true

# Git pull 更新
cd ~/tools/clawpanel
git pull --rebase

# 重新安装依赖（需要 devDependencies 中的 vite 进行构建）
npm install

# 重新构建
npm run build

# 验证
if [ ! -f ~/tools/clawpanel/package.json ]; then
  log_error "Update verification failed"
  exit 1
fi

log_success "ClawPanel updated successfully"