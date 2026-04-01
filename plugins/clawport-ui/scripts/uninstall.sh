#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# ClawPort UI 卸载脚本


log_info "Uninstalling ClawPort UI..."

# 停止进程
pkill -f "clawport" 2>/dev/null || true
pkill -f "next.*server" 2>/dev/null || true

# npm 卸载
npm uninstall -g clawport-ui 2>/dev/null || true

# 获取路径
NPM_ROOT=$(npm root -g 2>/dev/null)
NPM_PREFIX=$(npm prefix -g 2>/dev/null)
CLAWPORT_PATH="$NPM_ROOT/clawport-ui"
CLAWPORT_BIN="$NPM_PREFIX/bin/clawport"

# 清理目录和链接
[ -d "$CLAWPORT_PATH" ] && rm -rf "$CLAWPORT_PATH" 2>/dev/null || true
[ -L "$CLAWPORT_BIN" ] && rm -f "$CLAWPORT_BIN" 2>/dev/null || true

rm -rf ~/supervisor/clawport-ui.conf 2>/dev/null || true
rm -rf ~/supervisor/clawport-ui.sh 2>/dev/null || true

# 保留配置文件（可选）
# rm -rf ~/.config/clawport-ui 2>/dev/null || true

log_info "User configuration preserved in ~/.config/clawport-ui"
log_success "ClawPort UI uninstalled"