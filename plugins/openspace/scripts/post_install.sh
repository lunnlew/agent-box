#!/bin/bash
set +e

# 导入共享函数库（容器内路径）
source /opt/lib.sh 2>/dev/null || {
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
}

# 获取插件定义目录
if [ -n "$PLUGINS_DEF_DIR" ]; then
  SCRIPT_DIR="$PLUGINS_DEF_DIR/openspace/scripts"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

PLUGIN_CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"

log_success "OpenSpace installation complete!"
echo ""
echo "=========================================="
echo " OpenSpace - AI Agent Self-Evolving Engine"
echo "=========================================="
echo ""
echo "CLI Commands:"
echo "  source ~/openspace-src/.venv/bin/activate"
echo "  openspace --query \"your task\""
echo "  openspace-mcp --help"
echo "  openspace-dashboard --port 7788"
echo ""
echo "Dashboard Access:"
echo "  Backend:  http://localhost:7788"
echo "  Frontend: http://localhost:5174"
echo ""
echo "MCP Integration (for Claude Code, etc.):"
echo "  Config example: ~/.openspace/mcp-config.example.json"
echo ""
echo "Environment Variables:"
echo "  OPENSPACE_API_KEY      - Cloud community API key (optional)"
echo "  OPENSPACE_PORT         - Dashboard backend port (default: 7788)"
echo "  OPENSPACE_FRONTEND_PORT - Dashboard frontend port (default: 5174)"
echo ""
echo "To start Dashboard:"
echo "  agentbox start openspace"
echo ""
echo "To integrate with Claude Code, add to ~/.claude/settings.json:"
cat "$PLUGIN_CONFIG_DIR/mcp-config.example.json" 2>/dev/null || echo "  (See ~/.openspace/mcp-config.example.json)"
echo ""