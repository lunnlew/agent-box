#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# HiClaw 更新脚本
# 拉取官方脚本重新安装


echo "正在更新 HiClaw..."

# 备份环境配置（转换为 Unix 格式并修复权限）
if [ -f ~/hiclaw-manager.env ]; then
  sed -i 's/\r$//' ~/hiclaw-manager.env 2>/dev/null || true
  chown agent:agent ~/hiclaw-manager.env 2>/dev/null || true
  chmod 644 ~/hiclaw-manager.env 2>/dev/null || true
  cp ~/hiclaw-manager.env ~/hiclaw-manager.env.bak
  echo "已备份配置文件到：~/hiclaw-manager.env.bak"
fi

# 停止现有容器
docker stop hiclaw-manager 2>/dev/null || true
docker rm hiclaw-manager 2>/dev/null || true

# 移除旧数据卷（全新安装）
docker volume rm hiclaw-data 2>/dev/null || true

# 重新执行安装脚本
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

# 获取 agentbox 容器的 /home/agent 挂载源路径（主机路径）
AGENT_HOME_SOURCE=$(docker inspect agentbox --format '{{range .Mounts}}{{if eq .Destination "/home/agent"}}{{.Source}}{{end}}{{end}}')

if [ -z "$AGENT_HOME_SOURCE" ]; then
  echo "警告：无法获取 agent home 挂载源，使用默认路径"
  AGENT_HOME_SOURCE="$HOME"
fi

echo "检测到的源路径: $AGENT_HOME_SOURCE"

# 将路径转换为 Docker 兼容格式
if [[ "$AGENT_HOME_SOURCE" =~ ^/host_mnt/ || "$AGENT_HOME_SOURCE" =~ ^/run/desktop/mnt/host/ ]]; then
  echo "使用 Docker Desktop Linux VM 格式路径"
elif [[ "$AGENT_HOME_SOURCE" =~ ^[A-Za-z]: ]]; then
  AGENT_HOME_SOURCE=$(echo "$AGENT_HOME_SOURCE" | sed 's|^\([A-Za-z]\):|\L\1|' | sed 's|:||g' | sed 's|\\|/|g' | sed 's|^|/|')
  echo "转换 Windows 路径为 Linux 格式: $AGENT_HOME_SOURCE"
else
  AGENT_HOME_SOURCE=$(python3 -c "import sys,re; s=sys.argv[1]; print(re.sub(r'/+', '/', s.replace(chr(92), '/')))" "$AGENT_HOME_SOURCE")
fi

# 如果 .env 中已配置 HICLAW_WORKSPACE_DIR 则使用配置的值，否则自动构建
if [ -n "$HICLAW_WORKSPACE_DIR" ]; then
  echo "配置的 HICLAW_WORKSPACE_DIR (原始): $HICLAW_WORKSPACE_DIR"
  # 需要将用户配置的路径转换为 Docker Desktop 兼容格式
  if [[ "$HICLAW_WORKSPACE_DIR" =~ ^[A-Za-z]: ]]; then
    # Windows 格式 (D:/path 或 D:\path)，转换为 /d/path 格式
    HICLAW_WORKSPACE_DIR=$(echo "$HICLAW_WORKSPACE_DIR" | tr "\\" "/" | sed "s|^\([A-Za-z]\):|/\L\1|")
    echo "转换后的 HICLAW_WORKSPACE_DIR: $HICLAW_WORKSPACE_DIR"
  elif [[ "$HICLAW_WORKSPACE_DIR" =~ ^~ ]]; then
    # ~ 开头的路径，展开为容器内路径，需要转换为对应的主机路径
    echo "警告: ~/ 路径格式在 Docker 挂载中无效，使用自动检测的主机路径"
    HICLAW_WORKSPACE_DIR="${AGENT_HOME_SOURCE}/hiclaw-manager"
    echo "自动设置 HICLAW_WORKSPACE_DIR: $HICLAW_WORKSPACE_DIR"
  fi
  export HICLAW_WORKSPACE_DIR
else
  export HICLAW_WORKSPACE_DIR="${AGENT_HOME_SOURCE}/hiclaw-manager"
  echo "自动设置 HICLAW_WORKSPACE_DIR: $HICLAW_WORKSPACE_DIR"
fi

# 获取 agentbox 容器的 /host-share 挂载源路径（主机路径）
HOST_SHARE_SOURCE=$(docker inspect agentbox --format '{{range .Mounts}}{{if eq .Destination "/host-share"}}{{.Source}}{{end}}{{end}}')

if [ -z "$HOST_SHARE_SOURCE" ]; then
  echo "警告：无法获取 host-share 挂载源，使用默认路径"
  HOST_SHARE_SOURCE="$HOME"
fi

echo "检测到的 host-share 源路径: $HOST_SHARE_SOURCE"

# 同样的路径转换逻辑
if [[ "$HOST_SHARE_SOURCE" =~ ^/host_mnt/ || "$HOST_SHARE_SOURCE" =~ ^/run/desktop/mnt/host/ ]]; then
  echo "使用 Docker Desktop Linux VM 格式路径"
elif [[ "$HOST_SHARE_SOURCE" =~ ^[A-Za-z]: ]]; then
  HOST_SHARE_SOURCE=$(echo "$HOST_SHARE_SOURCE" | tr "\\" "/" | sed "s|^\([A-Za-z]\):|/\L\1|")
  echo "转换 Windows 路径为 Linux 格式: $HOST_SHARE_SOURCE"
else
  HOST_SHARE_SOURCE=$(echo "$HOST_SHARE_SOURCE" | tr -s "/")
fi

echo "Host share source: $HOST_SHARE_SOURCE"

# 设置 HICLAW_HOST_SHARE_DIR 为主机路径，让官方脚本自己构建挂载参数
export HICLAW_HOST_SHARE_DIR="$HOST_SHARE_SOURCE"

curl -fsSL https://higress.ai/hiclaw/install.sh -o /tmp/hiclaw-install.sh
chmod +x /tmp/hiclaw-install.sh
bash /tmp/hiclaw-install.sh manager
rm -f /tmp/hiclaw-install.sh