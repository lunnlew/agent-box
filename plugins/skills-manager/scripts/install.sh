#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  # 如果不在容器内，定义简化版日志函数
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# 获取插件定义目录（支持容器内和本地两种环境）
if [ -n "$PLUGINS_DEF_DIR" ]; then
  SCRIPT_DIR="$PLUGINS_DEF_DIR/skills-manager/scripts"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

SKILLS_MANAGER_VERSION="${SKILLS_MANAGER_VERSION:-1.1.5}"

log_info "Installing Skills Manager..."

# 创建目录
mkdir -p ~/tools/appimages/Skills-Manager
mkdir -p ~/.skills-manager ~/logs
rm -rf ~/tools/appimages/Skills-Manager/* 2>/dev/null || true

# 下载 AppImage
log_info "Downloading Skills Manager v${SKILLS_MANAGER_VERSION}..."
curl -fsSL -o ~/tools/appimages/Skills-Manager/Skills-Manager.AppImage \
  "https://github.com/jiweiyeah/Skills-Manager/releases/download/v${SKILLS_MANAGER_VERSION}/Skills.Manager_${SKILLS_MANAGER_VERSION}_amd64.AppImage"

# 设置权限
chmod +x ~/tools/appimages/Skills-Manager/Skills-Manager.AppImage

# 提取 AppImage（Docker 容器没有 FUSE 支持）
log_info "Extracting AppImage..."
cd ~/tools/appimages/Skills-Manager && ./Skills-Manager.AppImage --appimage-extract 2>/dev/null || true

# 修复解压后的权限问题（squashfs 提取后文件属于 root，需要给所有用户权限）
log_info "Fixing permissions..."
chmod -R 755 ~/tools/appimages/Skills-Manager/squashfs-root 2>/dev/null || true
chmod +x ~/tools/appimages/Skills-Manager/squashfs-root/AppRun 2>/dev/null || true
if [ -f ~/tools/appimages/Skills-Manager/squashfs-root/AppRun.wrapped ]; then
  chmod +x ~/tools/appimages/Skills-Manager/squashfs-root/AppRun.wrapped 2>/dev/null || true
fi

# 复制启动脚本到可写目录
log_info "Copying startup script..."
if [ -f ~/plugins-config/skills-manager/scripts/start.sh ]; then
  cp ~/plugins-config/skills-manager/scripts/start.sh ~/tools/appimages/Skills-Manager/
  chmod +x ~/tools/appimages/Skills-Manager/start.sh
  log_info "Startup script copied successfully"
else
  log_warning "Startup script source not found at ~/plugins-config/skills-manager/scripts/start.sh"
  log_warning "Skipping startup script copy (service may fail to start)"
fi

# 验证安装
if [ ! -f ~/tools/appimages/Skills-Manager/squashfs-root/AppRun ]; then
  log_error "Installation failed: AppRun not found (AppImage extraction may have failed)"
  log_info "Please check network connection and retry: agentbox install skills-manager --force"
else
  log_success "Skills Manager installed successfully"
fi