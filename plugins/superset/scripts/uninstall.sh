#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# Superset 卸载脚本


log_info "Uninstalling Superset..."

# 停止进程
pkill -f "Superset" 2>/dev/null || true
pkill -f "AppRun" 2>/dev/null || true

# 清理安装目录
rm -rf ~/tools/appimages/Superset 2>/dev/null || true

rm -rf ~/supervisor/superset.conf 2>/dev/null || true
rm -rf ~/supervisor/superset.sh 2>/dev/null || true

# ⚠️ 保留用户配置
# rm -rf ~/.superset 2>/dev/null || true

log_success "Superset uninstalled"