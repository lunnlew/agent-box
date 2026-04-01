#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# CoPaw 卸载脚本


log_info "Uninstalling CoPaw..."

# 停止可能的进程
pkill -f "copaw" 2>/dev/null || true

# 清理安装的文件
rm -rf ~/.copaw/bin 2>/dev/null || true
rm -rf ~/.copaw/venv 2>/dev/null || true
rm -rf ~/.copaw/cache 2>/dev/null || true

# 清理可能的全局命令
rm -f ~/.local/bin/copaw 2>/dev/null || true

rm -rf ~/supervisor/copaw.conf 2>/dev/null || true
rm -rf ~/supervisor/copaw.sh 2>/dev/null || true

# ✅ 明确保留用户项目数据
# ~/.copaw/projects/ - 用户项目
# ~/.copaw/workflows/ - 用户工作流
# ~/.copaw/config/ - 用户配置
log_info "User projects preserved in ~/.copaw/projects"
log_info "User workflows preserved in ~/.copaw/workflows"

log_success "CoPaw uninstalled"