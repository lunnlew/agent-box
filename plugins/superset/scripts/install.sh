#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# Superset 安装脚本


log_info "Installing Superset..."

# 创建目录
mkdir -p ~/tools/appimages/Superset
mkdir -p ~/.superset ~/logs
rm -rf ~/tools/appimages/Superset/* 2>/dev/null || true

# 下载 AppImage
log_info "Downloading Superset v1.1.7..."
curl -fsSL -o ~/tools/appimages/Superset/Superset.AppImage \
  https://github.com/superset-sh/superset/releases/download/desktop-v1.1.7/superset-1.1.7-x86_64.AppImage

# 设置权限
chmod +x ~/tools/appimages/Superset/Superset.AppImage

# 提取 AppImage（Docker 容器没有 FUSE 支持）
log_info "Extracting AppImage..."
cd ~/tools/appimages/Superset && ./Superset.AppImage --appimage-extract 2>/dev/null || true

# 修复解压后的权限问题（squashfs 提取后文件属于 root，需要给所有用户权限）
log_info "Fixing permissions..."
chmod -R 755 ~/tools/appimages/Superset/squashfs-root 2>/dev/null || true
chmod +x ~/tools/appimages/Superset/squashfs-root/AppRun 2>/dev/null || true
if [ -f ~/tools/appimages/Superset/squashfs-root/AppRun.wrapped ]; then
  chmod +x ~/tools/appimages/Superset/squashfs-root/AppRun.wrapped 2>/dev/null || true
fi

# 复制启动脚本
if [ -f /home/agent/plugins-config/superset/scripts/start.sh ]; then
  cp /home/agent/plugins-config/superset/scripts/start.sh ~/tools/appimages/Superset/
  chmod +x ~/tools/appimages/Superset/start.sh
fi

# 验证安装
if [ ! -f ~/tools/appimages/Superset/squashfs-root/AppRun ]; then
  log_error "Installation failed: AppRun not found"
  exit 1
fi

log_success "Superset installed successfully"