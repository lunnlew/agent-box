#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# CoPaw Docker 安装后提示

echo ""
echo "=============================================="
echo "  CoPaw Docker 安装完成"
echo "=============================================="
echo ""
echo "访问地址: http://127.0.0.1:${COPAW_DOCKER_PORT:-8088}/"
echo ""
echo "数据持久化:"
echo "  - 配置、记忆与 Skills: copaw-data volume"
echo "  - 模型配置与 API Key: copaw-secrets volume"
echo ""
echo "镜像配置:"
echo "  - 默认: agentscope/copaw:latest (稳定版)"
echo "  - 预发布: agentscope/copaw:pre"
echo "  - 国内镜像: agentscope-registry.ap-southeast-1.cr.aliyuncs.com/agentscope/copaw"
echo ""
echo "设置镜像:"
echo "  export COPAW_DOCKER_IMAGE=agentscope/copaw:pre"
echo "  # 或使用国内镜像:"
echo "  export COPAW_DOCKER_IMAGE=agentscope-registry.ap-southeast-1.cr.aliyuncs.com/agentscope/copaw:latest"
echo ""
echo "设置 API Key:"
echo "  export DASHSCOPE_API_KEY=xxx"
echo "  # 或在 docker run 时传入:"
echo "  docker run -e DASHSCOPE_API_KEY=xxx ..."
echo "  # 或使用 --env-file .env"
echo ""
echo "=============================================="