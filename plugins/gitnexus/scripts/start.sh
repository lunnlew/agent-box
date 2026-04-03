#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}


# 获取插件定义目录（支持容器内和本地两种环境）
if [ -n "$PLUGINS_DEF_DIR" ]; then
  SCRIPT_DIR="$PLUGINS_DEF_DIR/gitnexus/scripts"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

GITNEXUS_PORT="${GITNEXUS_PORT:-4747}"
GITNEXUS_WEB_PORT="${GITNEXUS_WEB_PORT:-5173}"
GITNEXUS_REPOS="${GITNEXUS_REPOS:-}"
GITNEXUS_AUTO_INDEX="${GITNEXUS_AUTO_INDEX:-false}"

echo "Starting GitNexus services..."
echo "  Bridge Server: port $GITNEXUS_PORT"
echo "  Web UI: port $GITNEXUS_WEB_PORT"

# 清理旧容器
docker rm -f gitnexus-bridge 2>/dev/null || true
docker rm -f gitnexus-web 2>/dev/null || true

sleep 1

# 获取 agentbox 容器中所有 /host-share 相关的挂载信息（使用共享函数）
get_inherited_mounts agentbox /host-share

# 自动从 agentbox 容器挂载信息获取 host 路径
AGENTBOX_MOUNT=$(get_mount_source agentbox /home/agent)

if [ -z "$AGENTBOX_MOUNT" ]; then
  echo "ERROR: Could not detect host path from agentbox mounts"
  echo "Falling back to local paths (data may not persist correctly)"
  GITNEXUS_DATA_PATH="$HOME/.gitnexus"
  WEB_DIST_PATH="$HOME/gitnexus-src/gitnexus-web/dist"
else
  echo "Detected host path: $AGENTBOX_MOUNT"
  GITNEXUS_DATA_PATH="${AGENTBOX_MOUNT}/.gitnexus"
  WEB_DIST_PATH="${AGENTBOX_MOUNT}/gitnexus-src/gitnexus-web/dist"
fi

# 构建 docker run 挂载参数 - 包含继承的 /host-share 挂载
DOCKER_VOLUMES="-v \"${GITNEXUS_DATA_PATH}:/root/.gitnexus\" ${VOLUME_ARGS}"

# 解析额外的仓库挂载路径
# 格式：/path/to/repo1[:name1],/path/to/repo2[:name2]
REPO_INDEX_LIST=""
if [ -n "$GITNEXUS_REPOS" ]; then
  echo ""
  echo "Processing extra repository mounts..."
  IFS=',' read -ra REPO_ENTRIES <<< "$GITNEXUS_REPOS"
  for entry in "${REPO_ENTRIES[@]}"; do
    entry=$(echo "$entry" | xargs)  # trim whitespace
    [ -z "$entry" ] && continue

    # 解析 host_path[:name] 格式（支持 Windows 驱动器路径）
    # Windows 路径格式：D:/path 或 D:\path（驱动器冒号后面跟着 / 或 \）
    # Unix 路径格式：/path 或相对路径
    if [[ "$entry" =~ ^[A-Za-z]:[\/\\] ]]; then
      # Windows 路径：跳过驱动器冒号，从第三个冒号开始分割
      # 例如 D:/path:name -> host_path=D:/path, repo_name=name
      host_path=$(echo "$entry" | cut -d':' -f1-2 | xargs)
      repo_name=$(echo "$entry" | cut -d':' -s -f3 | xargs)
    else
      # Unix 路径：正常处理
      host_path=$(echo "$entry" | cut -d':' -f1 | xargs)
      repo_name=$(echo "$entry" | cut -d':' -s -f2 | xargs)
    fi

    # Docker 可以直接处理 Windows 路径格式 (D:/path 或 D:\path)
    # 不在容器内检查路径是否存在（容器内无法识别 Windows 路径）
    # 只检查路径格式是否有效
    if [ -z "$host_path" ]; then
      echo "  WARNING: Empty path in GITNEXUS_REPOS, skipping"
      continue
    fi

    # 如果没有指定名称，使用目录名
    if [ -z "$repo_name" ]; then
      repo_name=$(basename "$host_path")
    fi

    # 容器内路径
    container_path="/host-share/${repo_name}"
    DOCKER_VOLUMES="$DOCKER_VOLUMES -v \"${host_path}:${container_path}\""
    REPO_INDEX_LIST="$REPO_INDEX_LIST $container_path"

    echo "  Mount: $host_path -> $container_path (name: $repo_name)"
  done
fi

# 确保 gitnexus 数据目录存在
mkdir -p "$GITNEXUS_DATA_PATH" 2>/dev/null || true

# 启动 Bridge Server 容器
echo ""
echo "Starting GitNexus Bridge Server..."
echo "  Data path: $GITNEXUS_DATA_PATH"

eval docker run -d \
  --name gitnexus-bridge \
  --restart unless-stopped \
  -p ${GITNEXUS_PORT}:4747 \
  ${DOCKER_VOLUMES} \
  gitnexus-runner:latest \
  gitnexus serve --port 4747 --host 0.0.0.0

# 等待服务启动
sleep 3

# 自动索引挂载的仓库（使用 --force 确保新建索引）
if [ -n "$REPO_INDEX_LIST" ] && [ "$GITNEXUS_AUTO_INDEX" = "true" ]; then
  echo ""
  echo "Auto-indexing mounted repositories..."
  for repo_path in $REPO_INDEX_LIST; do
    echo "  Indexing: $repo_path"
    docker exec gitnexus-bridge gitnexus analyze "$repo_path" --force 2>&1 | tail -10
  done
  echo "Auto-indexing completed."
fi

# 检查 Web UI 是否需要构建
if [ ! -f ~/gitnexus-src/gitnexus-web/dist/index.html ]; then
  echo ""
  echo "WARNING: Web UI not built yet."
  echo "Please build it first. See post_install instructions."
else
  # 启动 Web UI 容器
  echo ""
  echo "Starting GitNexus Web UI..."
  echo "  Web dist path: $WEB_DIST_PATH"

  docker run -d \
    --name gitnexus-web \
    --restart unless-stopped \
    -p ${GITNEXUS_WEB_PORT}:3000 \
    -v "${WEB_DIST_PATH}:/app" \
    gitnexus-runner:latest \
    bash -c "npx -y serve -s /app -l 3000"
fi

sleep 3
echo ""
echo "Container status:"
docker ps -a --filter "name=gitnexus" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 显示使用提示
if [ -n "$REPO_INDEX_LIST" ]; then
  echo ""
  echo "Indexed repositories:"
  docker exec gitnexus-bridge gitnexus list 2>&1 || true
fi