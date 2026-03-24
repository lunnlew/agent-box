#!/bin/bash
# DeerFlow 配置初始化脚本
# 用于创建默认配置文件

set -e

DEERFLOW_DIR="${1:-~/deer-flow}"

cd "$DEERFLOW_DIR"

# 创建 config.yaml
cat > config.yaml << 'CONFIGEOF'
models:
  - name: qwen-max
    display_name: Qwen Max
    use: langchain_openai:ChatOpenAI
    model: qwen-max
    api_key: $DASHSCOPE_API_KEY
    max_tokens: 4096
    temperature: 0.7

sandbox:
  use: local

mcp_servers: []
skills: []
CONFIGEOF

# 创建 .env
cat > .env << ENVEOF
# DeerFlow 环境配置
# 通义千问 API Key (推荐使用)
DASHSCOPE_API_KEY=your-dashscope-api-key-here

# 其他可选 API Keys
# OPENAI_API_KEY=your-openai-api-key-here
# OPENROUTER_API_KEY=your-openrouter-api-key-here
ENVEOF

echo "DeerFlow configuration files created in $DEERFLOW_DIR"
