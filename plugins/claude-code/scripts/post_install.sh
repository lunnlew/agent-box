#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}


echo ""
echo "============================================"
echo "  Claude Code 安装完成!"
echo "============================================"
echo ""
echo "配置文件：~/.claude.json"
echo "数据目录：~/.claude"
echo ""
echo "设置 API Key:"
echo "  export ANTHROPIC_API_KEY=your-key"
echo ""
echo "使用示例:"
echo "  claude           # 交互模式"
echo "  claude -p '...'  # 单次提示"
echo "============================================"
echo ""
echo "正在安装 CLI-Anything 插件..."
if command -v claude &>/dev/null; then
  log_info "Adding CLI-Anything plugin marketplace..."
  claude plugin marketplace add HKUDS/CLI-Anything 2>/dev/null && \
    log_success "CLI-Anything marketplace added" || \
    log_warning "Failed to add marketplace"

  log_info "Installing cli-anything plugin..."
  claude plugin install cli-anything 2>/dev/null && \
    log_success "cli-anything plugin installed" || \
    log_warning "Failed to install cli-anything plugin"

  log_info "Adding Superpowers plugin marketplace..."
  claude plugin marketplace add obra/superpowers-marketplace 2>/dev/null && \
    log_success "Superpowers marketplace added" || \
    log_warning "Failed to add Superpowers marketplace"

  log_info "Installing superpowers plugin..."
  claude plugin install superpowers@superpowers-marketplace 2>/dev/null && \
    log_success "superpowers plugin installed" || \
    log_warning "Failed to install superpowers plugin"
fi
echo ""