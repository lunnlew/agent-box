#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
}

PKG_NAME="@openai/codex"
PKG_PATH="$(npm root -g 2>/dev/null)/@openai/codex"
NPM_PREFIX=$(npm prefix -g 2>/dev/null)
PKG_BIN="$NPM_PREFIX/bin/codex"

log_info "Uninstalling OpenAI Codex..."

# npm 卸载
npm uninstall -g "$PKG_NAME" 2>/dev/null || true

# 清理残留目录
[ -d "$PKG_PATH" ] && rm -rf "$PKG_PATH" 2>/dev/null || true
[ -L "$PKG_BIN" ] && rm -f "$PKG_BIN" 2>/dev/null || true
[ -f "$PKG_BIN" ] && rm -f "$PKG_BIN" 2>/dev/null || true

# 清理临时目录
for tmp_dir in "$(npm root -g 2>/dev/null)"/.codex-*; do
  [ -d "$tmp_dir" ] && rm -rf "$tmp_dir" 2>/dev/null || true
done

log_success "OpenAI Codex uninstalled"