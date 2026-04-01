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
echo "  OpenAI Codex 安装完成!"
echo "============================================"
echo ""
echo "配置目录：~/.codex"
echo ""
echo "设置 API Key (可选):"
echo "  export OPENAI_API_KEY=your-key"
echo ""
echo "使用示例:"
echo "  codex           # 交互模式"
echo "============================================"
echo ""