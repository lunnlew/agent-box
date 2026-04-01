#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

PLUGIN_CONFIG_DIR="$(dirname "$(dirname "$0")")/config"

log_info "Installing OpenSpace..."

# 创建数据目录
mkdir -p ~/.openspace
mkdir -p ~/logs
mkdir -p ~/bin

# 清理旧安装
if [ -d ~/openspace-src ]; then
  log_info "Cleaning existing installation..."
  rm -rf ~/openspace-src
fi

# 克隆源码 - 使用浅克隆 + 手动删除大文件
log_info "Cloning OpenSpace repository..."
git clone --depth 1 --single-branch https://github.com/HKUDS/OpenSpace.git ~/openspace-src 2>&1 || {
  log_error "Failed to clone OpenSpace repository"
  exit 1
}

cd ~/openspace-src

# 删除不需要的大文件目录以节省空间
log_info "Removing large files (assets, showcase, gdpval_bench)..."
rm -rf assets showcase gdpval_bench 2>/dev/null || true

# 修复权限（git clone 可能以 root 身份创建文件）
log_info "Fixing permissions..."
chown -R agent:agent ~/openspace-src 2>/dev/null || chmod -R u+rw ~/openspace-src 2>/dev/null || true

log_info "Source directory ready: $(du -sh ~/openspace-src 2>/dev/null | cut -f1)"

# 检查 openspace 包目录是否存在
if [ ! -d "openspace" ]; then
  log_error "openspace package directory not found after clone!"
  log_info "Directory contents:"
  ls -la
  exit 1
fi

# 创建 Python 虚拟环境
log_info "Creating Python virtual environment..."
python3 -m venv --clear .venv

# 验证 venv 创建成功
if [ ! -d .venv ] || [ ! -f .venv/bin/python ]; then
  log_error "Failed to create virtual environment"
  exit 1
fi

log_info "Installing OpenSpace package..."

# 安装（不使用缓存，禁用 user 模式）
.venv/bin/pip install --no-cache-dir --no-user -e . 2>&1 | tail -20

# 验证安装
log_info "Verifying installation..."

FAILED_CMDS=""

for cmd in openspace openspace-mcp openspace-dashboard; do
  if [ -f ".venv/bin/$cmd" ]; then
    log_success "  $cmd - OK"
    # 创建 wrapper
    cat > ~/bin/$cmd << EOF
#!/bin/bash
exec ~/openspace-src/.venv/bin/$cmd "\$@"
EOF
    chmod +x ~/bin/$cmd
  else
    log_warning "  $cmd - FAILED"
    FAILED_CMDS="$FAILED_CMDS $cmd"
  fi
done

# 复制配置示例
mkdir -p ~/.openspace
if [ -f "$PLUGIN_CONFIG_DIR/.env.example" ]; then
  cp "$PLUGIN_CONFIG_DIR/.env.example" ~/.openspace/.env.example 2>/dev/null || true
fi

if [ -f "$PLUGIN_CONFIG_DIR/mcp-config.example.json" ]; then
  cp "$PLUGIN_CONFIG_DIR/mcp-config.example.json" ~/.openspace/mcp-config.example.json 2>/dev/null || true
fi

# 添加 ~/bin 到 PATH
if ! grep -q 'export PATH="$HOME/bin:$PATH"' ~/.bashrc 2>/dev/null; then
  echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
fi

# 结果
if [ -z "$FAILED_CMDS" ]; then
  log_success "OpenSpace installed successfully!"
  log_info ""
  log_info "Available commands (in ~/bin/):"
  ls -la ~/bin/openspace* 2>/dev/null || true
  log_info ""
  log_info "Start Dashboard: agentbox start openspace"
  exit 0
else
  log_warning "Installation completed but some commands failed:$FAILED_CMDS"
  log_info "Check: ls -la ~/openspace-src/.venv/bin/"
  exit 0
fi