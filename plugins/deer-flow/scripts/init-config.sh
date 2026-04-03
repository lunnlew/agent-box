#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# DeerFlow 配置初始化脚本
# 用于创建默认配置文件

set -e

DEERFLOW_DIR="${1:-~/deer-flow}"

cd "$DEERFLOW_DIR"

# 创建 config.yaml
cat > config.yaml << 'CONFIGEOF'
tool_groups:
  - name: web
  - name: file:read
  - name: file:write
  - name: bash
  
models:
  - name: qwen3.5-plus
    display_name: Qwen 3.5 Plus
    use: langchain_openai:ChatOpenAI
    model: qwen3.5-plus
    api_key: $DASHSCOPE_API_KEY
    base_url: https://coding.dashscope.aliyuncs.com/v1
    max_tokens: 4096
    temperature: 0.7

sandbox:
  use: deerflow.sandbox.local:LocalSandboxProvider

channels:
  langgraph_url: http://langgraph:2024
  gateway_url: http://gateway:8001
CONFIGEOF

# 创建 .env
cat > .env << 'ENVEOF'
# DeerFlow 环境配置
# 通义千问 API Key (推荐使用)
DASHSCOPE_API_KEY=$DASHSCOPE_API_KEY

# 其他可选 API Keys
# OPENAI_API_KEY=your-openai-api-key-here
# OPENROUTER_API_KEY=your-openrouter-api-key-here
ENVEOF

# 创建 frontend/.env (Next.js 前端配置)
mkdir -p frontend
cat > frontend/.env << FRONTENDENVEOF
# DeerFlow Frontend 环境配置
# Backend API URLs (optional, uses nginx proxy by default)
# NEXT_PUBLIC_BACKEND_BASE_URL="http://localhost:8001"
# NEXT_PUBLIC_LANGGRAPH_BASE_URL="http://localhost:2024"

# LangGraph API base URL
# Default: /api/langgraph (uses langgraph dev server via nginx)
# NEXT_PUBLIC_LANGGRAPH_BASE_URL=/api/langgraph-compat
FRONTENDENVEOF

echo "DeerFlow configuration files created in $DEERFLOW_DIR"
