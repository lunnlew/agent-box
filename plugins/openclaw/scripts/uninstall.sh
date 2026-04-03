#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# OpenClaw 卸载脚本


log_info "Uninstalling OpenClaw..."

# 停止 Gateway
openclaw gateway stop 2>/dev/null || true

# npm 卸载
npm uninstall -g openclaw 2>/dev/null || true

rm -rf ~/supervisor/openclaw.conf 2>/dev/null || true
rm -rf ~/supervisor/openclaw.sh 2>/dev/null || true

# 清理安装目录
# npm 10.x 不支持 bin -g，使用 prefix + /bin 替代
NPM_PREFIX=$(npm prefix -g 2>/dev/null)
NPM_ROOT=$(npm root -g 2>/dev/null)
OPENCLAW_PATH="$NPM_ROOT/openclaw"
OPENCLAW_BIN="$NPM_PREFIX/bin/openclaw"

[ -d "$OPENCLAW_PATH" ] && rm -rf "$OPENCLAW_PATH" 2>/dev/null || true
[ -L "$OPENCLAW_BIN" ] && rm -f "$OPENCLAW_BIN" 2>/dev/null || true

# ⚠️ 保留用户配置和数据（devices、配置等）
# 如需完全清理，手动执行：rm -rf ~/.openclaw
log_info "User data preserved in ~/.openclaw"

log_success "OpenClaw uninstalled"