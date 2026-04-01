#!/bin/bash
set +e

# 导入共享函数库
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
}

log_info "Uninstalling DeerFlow..."

# 停止服务
cd ~/deer-flow 2>/dev/null || true
make docker-stop 2>/dev/null || true

# 删除容器
docker stop deer-flow 2>/dev/null || true
docker rm deer-flow 2>/dev/null || true

# 清理源代码（保留用户配置）
log_info "Preserving user configuration in ~/deer-flow/.env and ~/deer-flow/config.yaml"
if [ -d ~/deer-flow ]; then
  # 备份配置
  cp ~/deer-flow/.env ~/deer-flow.env.bak 2>/dev/null || true
  cp ~/deer-flow/config.yaml ~/deer-flow.config.yaml.bak 2>/dev/null || true
  # 删除源代码
  rm -rf ~/deer-flow
  log_info "Configuration backed up"
fi

log_success "DeerFlow uninstalled"