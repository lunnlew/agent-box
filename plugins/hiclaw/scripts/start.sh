#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# HiClaw 启动脚本

# 检查容器是否已存在
if docker ps -a --filter name=hiclaw-manager -q | grep -q .; then
  # 容器存在，直接启动
  if docker ps --filter name=hiclaw-manager --filter status=running -q | grep -q .; then
    echo "HiClaw Manager 已在运行中"
    exit 0
  fi
  echo "正在启动 HiClaw Manager..."
  docker start hiclaw-manager
  sleep 3
  if docker ps --filter name=hiclaw-manager --filter status=running -q | grep -q .; then
    echo "HiClaw Manager 启动成功"
    exit 0
  else
    echo "错误：HiClaw Manager 启动失败，请检查日志：docker logs hiclaw-manager"
    exit 1
  fi
else
  # 容器不存在，执行安装
  echo "HiClaw Manager 未安装，正在执行安装..."

  # 转换 env 文件为 Unix 格式并修复权限（解决 Windows 换行符和权限问题）
  if [ -f ~/hiclaw-manager.env ]; then
    sed -i 's/\r$//' ~/hiclaw-manager.env 2>/dev/null || true
    chown agent:agent ~/hiclaw-manager.env 2>/dev/null || true
    chmod 644 ~/hiclaw-manager.env 2>/dev/null || true
  fi

  # 设置环境变量（非交互模式，使用默认值）
  export HICLAW_NON_INTERACTIVE=1
  # 设置数据持久化到 Docker volume
  export HICLAW_DATA_DIR=hiclaw-data
  # 端口配置（使用官方变量名）
  export HICLAW_PORT_GATEWAY=${HICLAW_PORT_GATEWAY:-18080}
  export HICLAW_PORT_CONSOLE=${HICLAW_PORT_CONSOLE:-18001}
  export HICLAW_PORT_ELEMENT_WEB=${HICLAW_PORT_ELEMENT_WEB:-18088}
  # LLM 提供商配置（非交互模式需要预设）
  export HICLAW_LLM_PROVIDER=${HICLAW_LLM_PROVIDER:-qwen}
  export HICLAW_LLM_MODEL=${HICLAW_LLM_MODEL:-qwen3.5-plus}
  export HICLAW_LLM_API_KEY=${HICLAW_LLM_API_KEY:-${DASHSCOPE_API_KEY:-sk-dummy-key-for-test}}

  # 获取 agentbox 容器的 /home/agent 挂载源路径（使用共享函数）
AGENT_HOME_SOURCE=$(get_mount_source agentbox /home/agent)

if [ -z "$AGENT_HOME_SOURCE" ]; then
  echo "警告：无法获取 agent home 挂载源，使用默认路径"
  AGENT_HOME_SOURCE="$HOME"
fi

echo "检测到的源路径: $AGENT_HOME_SOURCE"

# 如果 .env 中已配置 HICLAW_WORKSPACE_DIR 则使用配置的值，否则自动构建
if [ -n "$HICLAW_WORKSPACE_DIR" ]; then
  echo "使用配置的 HICLAW_WORKSPACE_DIR: $HICLAW_WORKSPACE_DIR"
else
  export HICLAW_WORKSPACE_DIR="${AGENT_HOME_SOURCE}/hiclaw-manager"
  echo "自动设置 HICLAW_WORKSPACE_DIR: $HICLAW_WORKSPACE_DIR"
fi

# 获取 agentbox 容器中所有 /host-share 相关的挂载信息（使用共享函数）
get_inherited_mounts agentbox /host-share

# 设置 HICLAW_HOST_SHARE_MOUNTS 为挂载信息，供官方脚本使用
export HICLAW_HOST_SHARE_MOUNTS="$HOST_SHARE_MOUNTS"
export HICLAW_HOST_SHARE_VOLUME_ARGS="$VOLUME_ARGS"

echo "Host share mounts: $HOST_SHARE_MOUNTS"

  # 执行安装脚本
  curl -fsSL https://higress.ai/hiclaw/install.sh -o /tmp/hiclaw-install.sh
  chmod +x /tmp/hiclaw-install.sh
  bash /tmp/hiclaw-install.sh manager
  rm -f /tmp/hiclaw-install.sh
fi