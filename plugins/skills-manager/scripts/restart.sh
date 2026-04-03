#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}


# Skills Manager 重启脚本

# 获取插件定义目录
if [ -n "$PLUGINS_DEF_DIR" ]; then
  SCRIPT_DIR="$PLUGINS_DEF_DIR/skills-manager/scripts"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

echo "Restarting Skills Manager..."

# 停止服务
bash "$SCRIPT_DIR/stop.sh"

sleep 2

# 启动服务
bash "$SCRIPT_DIR/start.sh"