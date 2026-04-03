#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# ============================================
# DeerFlow Docker Root Path Setup
# ============================================
# 将容器内路径转换为 Docker Desktop 可识别的 Windows 主机路径
# ============================================

# 获取 DeerFlow 目录的容器内路径 (默认 ~/deer-flow)
CONTAINER_DEERFLOW_ROOT="${1:-$HOME/deer-flow}"

# 从 docker inspect 获取 /home/agent 的实际 Windows 主机路径
# 输出格式："D:\\AI-workspace\\agent-box\\data:/home/agent:rw"
# 使用 awk 提取第一个字段（Windows 路径）
HOST_DATA_PATH=$(docker inspect agentbox 2>/dev/null | grep '/home/agent:' | head -1 | awk -F':' '{print $1":"$2}' | tr -d '"[:space:]')

# 处理获取到的路径
if [ -n "$HOST_DATA_PATH" ]; then
    # 检查是否是 Windows 路径格式（包含 :）
    if echo "$HOST_DATA_PATH" | grep -q ':'; then
        # 直接使用 Windows 路径格式，但转换为 Unix 风格的分隔符
        # D:\AI-workspace\agent-box\data → D:/AI-workspace/agent-box/data
        WINDOWS_DEERFLOW_ROOT=$(echo "$HOST_DATA_PATH" | sed 's/\\/\//g' | sed 's/\/\+/\//g')
        WINDOWS_DEERFLOW_ROOT="${WINDOWS_DEERFLOW_ROOT}/deer-flow"
        echo "$WINDOWS_DEERFLOW_ROOT"
        exit 0
    fi
fi

# 如果无法检测到主机挂载路径，返回容器内路径
# Docker Desktop 在某些配置下会自动处理路径映射
echo "$CONTAINER_DEERFLOW_ROOT"
