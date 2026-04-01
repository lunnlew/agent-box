#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# 获取插件定义目录
if [ -n "$PLUGINS_DEF_DIR" ]; then
  SCRIPT_DIR="$PLUGINS_DEF_DIR/openclaw-manager/scripts"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

OPENCLAW_MANAGER_VERSION="${OPENCLAW_MANAGER_VERSION:-0.0.7}"

log_info "Updating OpenClaw Manager..."

# 停止当前服务
pkill -f "OpenClaw-Manager" 2>/dev/null || true
pkill -f "x11vnc.*5901" 2>/dev/null || true
pkill -f "websockify.*6081" 2>/dev/null || true

# 清理旧版本
rm -rf ~/tools/appimages/OpenClaw-Manager 2>/dev/null || true

# 重新安装
mkdir -p ~/tools/appimages/OpenClaw-Manager

log_info "Downloading OpenClaw Manager v${OPENCLAW_MANAGER_VERSION}..."
curl -fsSL -o ~/tools/appimages/OpenClaw-Manager/OpenClaw-Manager.AppImage \
  "https://github.com/miaoxworld/openclaw-manager/releases/download/v${OPENCLAW_MANAGER_VERSION}/OpenClaw.Manager_${OPENCLAW_MANAGER_VERSION}_amd64.AppImage"

chmod +x ~/tools/appimages/OpenClaw-Manager/OpenClaw-Manager.AppImage

log_info "Extracting AppImage..."
cd ~/tools/appimages/OpenClaw-Manager && ./OpenClaw-Manager.AppImage --appimage-extract 2>/dev/null || true

# 修复解压后的权限问题
log_info "Fixing permissions..."
chmod -R 755 ~/tools/appimages/OpenClaw-Manager/squashfs-root 2>/dev/null || true
chmod +x ~/tools/appimages/OpenClaw-Manager/squashfs-root/AppRun 2>/dev/null || true
if [ -f ~/tools/appimages/OpenClaw-Manager/squashfs-root/AppRun.wrapped ]; then
  chmod +x ~/tools/appimages/OpenClaw-Manager/squashfs-root/AppRun.wrapped 2>/dev/null || true
fi

# 复制启动脚本
log_info "Copying startup script..."
if [ -f ~/plugins-config/openclaw-manager/scripts/start.sh ]; then
  cp ~/plugins-config/openclaw-manager/scripts/start.sh ~/tools/appimages/OpenClaw-Manager/
  chmod +x ~/tools/appimages/OpenClaw-Manager/start.sh
  log_info "Startup script copied successfully"
else
  log_warning "Startup script source not found"
fi

# 验证
if [ ! -f ~/tools/appimages/OpenClaw-Manager/squashfs-root/AppRun ]; then
  log_error "Update verification failed: AppRun not found"
  log_info "Please retry: agentbox install openclaw-manager --force"
else
  log_success "OpenClaw Manager updated successfully"
fi