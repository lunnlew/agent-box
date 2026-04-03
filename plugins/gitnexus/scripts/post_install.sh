#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# 检查 Web UI 是否已构建
WEB_UI_BUILT=false
if [ -f ~/gitnexus-src/gitnexus-web/dist/index.html ]; then
  WEB_UI_BUILT=true
fi

echo ""
echo "============================================"
echo "  GitNexus 安装完成!"
echo "============================================"
echo ""
echo "📦 组件 (Docker 容器):"
echo "  ✅ Bridge Server (端口 ${GITNEXUS_PORT:-4747})"
if [ "$WEB_UI_BUILT" = true ]; then
  echo "  ✅ Web UI (端口 ${GITNEXUS_WEB_PORT:-5173}) - 已自动构建"
else
  echo "  ⚠️  Web UI (端口 ${GITNEXUS_WEB_PORT:-5173}) - 构建失败，需手动构建"
fi
echo ""

if [ "$WEB_UI_BUILT" = false ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Web UI 构建失败，请手动构建 (在 host 上运行):"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "  # 获取数据目录路径"
  echo "  DATA_DIR=\$(docker inspect agentbox --format '{{range .Mounts}}{{if eq .Destination \"/home/agent\"}}{{.Source}}{{end}}{{end}}')"
  echo ""
  echo "  # 构建 gitnexus-shared"
  echo "  docker run --rm -v \${DATA_DIR}/gitnexus-src:/app -w //app/gitnexus-shared gitnexus-runner:latest bash -c 'npm install && npm run build'"
  echo ""
  echo "  # 构建 gitnexus-web"
  echo "  docker run --rm -v \${DATA_DIR}/gitnexus-src:/app -w //app/gitnexus-web gitnexus-runner:latest bash -c 'npm install && npm run build'"
  echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "启动服务:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  agentbox start gitnexus"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Web UI 访问:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  本地部署: http://localhost:${GITNEXUS_WEB_PORT:-5173}"
echo "  官方在线: https://gitnexus.vercel.app"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CLI 命令:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  docker exec gitnexus-bridge npx -y gitnexus list"
echo ""
echo "============================================"
echo ""