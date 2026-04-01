#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AgentBox Dashboard Server
"""

import http.server
import json
import socket
import os
from urllib.parse import urlparse

# Configuration
PORT = int(os.environ.get('BOARD_PORT', 8888))
BOARD_DIR = os.path.expanduser('~/plugins-config/board')


def get_openclaw_token():
    """Get OpenClaw token from env or config file"""
    # First try environment variable
    token = os.environ.get('OPENCLAW_GATEWAY_TOKEN', '')
    if token:
        return token

    # Try to read from openclaw.json config file
    config_path = os.path.expanduser('~/.openclaw/openclaw.json')
    try:
        if os.path.exists(config_path):
            with open(config_path, 'r', encoding='utf-8') as f:
                config = json.load(f)
                gateway = config.get('gateway', {})
                auth = gateway.get('auth', {})
                if auth.get('mode') == 'token':
                    token = auth.get('token', '')
                    if token:
                        return token
    except Exception as e:
        print('Failed to read openclaw.json: {}'.format(e))

    return ''


# OpenClaw token
OPENCLAW_TOKEN = get_openclaw_token()

# Host detection: HiClaw services run on host machine, use host.docker.internal
# Docker Desktop provides this via extra_hosts in docker-compose.yml
HOST_CHECK = os.environ.get('BOARD_CHECK_HOST', '127.0.0.1')

# Services configuration
# internal_port: 容器内部监听端口（固定值，用于状态检测）
# external_port: 外部访问端口（通过环境变量配置，用于前端显示）
# check_host: 检测地址（默认 127.0.0.1，HiClaw 服务使用 host.docker.internal）
SERVICES = {
    'vscode-server': {
        'internal_port': 8080,
        'external_port': int(os.environ.get('VSCODE_PORT', 8080)),
        'name': 'VS Code Server',
        'icon': '💻',
        'desc': '浏览器中的完整 VS Code IDE，支持代码编辑、调试、Git 等功能',
        'path': '',
        'color': 'blue',
        'category': 'dev',
        'check_host': '127.0.0.1'
    },
    'web-terminal': {
        'internal_port': 7681,
        'external_port': int(os.environ.get('WEB_TERMINAL_PORT', 7681)),
        'name': 'Web Terminal',
        'icon': '🖥️',
        'desc': '浏览器终端，直接访问容器命令行环境',
        'path': '',
        'color': 'green',
        'category': 'dev',
        'check_host': '127.0.0.1'
    },
    'hiclaw-gateway': {
        'internal_port': int(os.environ.get('HICLAW_PORT_GATEWAY', 18080)),
        'external_port': int(os.environ.get('HICLAW_PORT_GATEWAY', 18080)),
        'name': 'HiClaw Gateway',
        'icon': '🌐',
        'desc': 'HiClaw Higress 网关入口',
        'path': '',
        'color': 'blue',
        'category': 'ai',
        'check_host': 'host.docker.internal'
    },
    'hiclaw-console': {
        'internal_port': int(os.environ.get('HICLAW_PORT_CONSOLE', 18001)),
        'external_port': int(os.environ.get('HICLAW_PORT_CONSOLE', 18001)),
        'name': 'HiClaw Console',
        'icon': '🎛️',
        'desc': 'HiClaw 管理控制台',
        'path': '',
        'color': 'purple',
        'category': 'ai',
        'check_host': 'host.docker.internal'
    },
    'hiclaw-element': {
        'internal_port': int(os.environ.get('HICLAW_PORT_ELEMENT_WEB', 18088)),
        'external_port': int(os.environ.get('HICLAW_PORT_ELEMENT_WEB', 18088)),
        'name': 'HiClaw Element',
        'icon': '💬',
        'desc': 'HiClaw Matrix 消息客户端',
        'path': '',
        'color': 'green',
        'category': 'ai',
        'check_host': 'host.docker.internal'
    },
    'openclaw': {
        'internal_port': 18789,
        'external_port': int(os.environ.get('OPENCLAW_PORT', 18789)),
        'name': 'OpenClaw Gateway',
        'icon': '🤖',
        'desc': '个人 AI 助手网关，支持多渠道消息平台接入',
        'path': '#token=' + OPENCLAW_TOKEN if OPENCLAW_TOKEN else '',
        'color': 'purple',
        'badge': 'popular',
        'category': 'ai',
        'check_host': '127.0.0.1'
    },
    'openclaw-dashboard': {
        'internal_port': 7000,
        'external_port': int(os.environ.get('DASHBOARD_PORT', 7000)),
        'name': 'OpenClaw Dashboard',
        'icon': '📊',
        'desc': 'OpenClaw AI Agent 官方可视化管理面板（纯 Web 服务）',
        'path': '',
        'color': 'blue',
        'category': 'ai',
        'check_host': '127.0.0.1'
    },
    'copaw': {
        'internal_port': 8088,
        'external_port': int(os.environ.get('COPAW_PORT', 8088)),
        'name': 'CoPaw Gateway',
        'icon': '🐾',
        'desc': 'AgentScope AI 编程助手网关',
        'path': '',
        'color': 'pink',
        'badge': 'new',
        'category': 'ai',
        'check_host': '127.0.0.1'
    },
    'skills-manager': {
        'internal_port': 6080,
        'external_port': int(os.environ.get('SKILLS_MANAGER_NOVNC_PORT', 6080)),
        'name': 'Skills Manager',
        'icon': '📚',
        'desc': 'AI 编程助手技能管理工具，通过 noVNC 浏览器访问',
        'path': '/vnc.html?autoconnect=true&reconnect=true&resize=scale',
        'color': 'cyan',
        'category': 'tools',
        'check_host': '127.0.0.1'
    },
    'openclaw-manager': {
        'internal_port': 6081,
        'external_port': int(os.environ.get('OPENCLAW_MANAGER_NOVNC_PORT', 6081)),
        'name': 'OpenClaw Manager',
        'icon': '🎮',
        'desc': 'OpenClaw AI Agent 桌面管理工具（通过 noVNC 浏览器访问）',
        'path': '/vnc.html?autoconnect=true&reconnect=true&resize=scale',
        'color': 'blue',
        'category': 'ai',
        'check_host': '127.0.0.1'
    },
    # 'superset': {
    #     'internal_port': 6081,
    #     'external_port': int(os.environ.get('SUPERSET_NOVNC_PORT', 6081)),
    #     'name': 'Superset',
    #     'icon': '🔭',
    #     'desc': '强大的桌面集成开发环境，通过 noVNC 浏览器访问',
    #     'path': '/vnc.html?autoconnect=true&reconnect=true&resize=scale',
    #     'color': 'cyan',
    #     'category': 'tools',
    #     'check_host': '127.0.0.1'
    # },
    'clawpanel': {
        'internal_port': 1420,
        'external_port': int(os.environ.get('CLAWPANEL_PORT', 1420)),
        'name': 'ClawPanel',
        'icon': '🎯',
        'desc': 'OpenClaw 可视化管理面板，内置 AI 助手一键安装配置诊断',
        'path': '',
        'color': 'indigo',
        'badge': 'new',
        'category': 'ai',
        'check_host': '127.0.0.1'
    },
    'clawport-ui': {
        'internal_port': 3000,
        'external_port': int(os.environ.get('CLAWPORT_PORT', 3000)),
        'name': 'ClawPort UI',
        'icon': '🎮',
        'desc': 'OpenClaw AI Agent 可视化管理中心（Org Map、Chat、Kanban、Cron 监控）',
        'path': '',
        'color': 'purple',
        'badge': 'new',
        'category': 'ai',
        'check_host': '127.0.0.1'
    },
    'deer-flow': {
        'internal_port': 2026,
        'external_port': int(os.environ.get('DEERFLOW_PORT', 2026)),
        'name': 'DeerFlow',
        'icon': '🦌',
        'desc': 'DeerFlow - 开源 Super Agent Harness（sub-agents、memory、sandbox）',
        'path': '',
        'color': 'green',
        'badge': 'new',
        'category': 'ai',
        'check_host': 'host.docker.internal'
    },
    'gitnexus': {
        'internal_port': 4747,
        'external_port': int(os.environ.get('GITNEXUS_PORT', 4747)),
        'name': 'GitNexus Bridge',
        'icon': '🔗',
        'desc': 'GitNexus Bridge Server - 连接本地索引，供 Web UI 和 MCP 使用',
        'path': '',
        'color': 'indigo',
        'category': 'tools',
        'check_host': 'host.docker.internal'
    },
    'gitnexus-web': {
        'internal_port': 5173,
        'external_port': int(os.environ.get('GITNEXUS_WEB_PORT', 5173)),
        'name': 'GitNexus Web UI',
        'icon': '🕸️',
        'desc': 'GitNexus 代码知识图谱探索器 - 可视化代码结构和依赖关系',
        'path': '',
        'color': 'purple',
        'badge': 'new',
        'category': 'tools',
        'check_host': 'host.docker.internal'
    }
}

CLI_TOOLS = {
    'claude-code': {
        'name': 'Claude Code CLI',
        'icon': '🧠',
        'desc': 'Anthropic 官方 AI 编程助手命令行工具，点击复制命令',
        'command': 'claude',
        'color': 'orange',
        'category': 'cli'
    },
    'qwen-code': {
        'name': 'Qwen Code CLI',
        'icon': '☁️',
        'desc': '阿里云通义千问 AI 编程助手命令行工具',
        'command': 'qwen',
        'color': 'orange',
        'category': 'cli'
    },
    'opencode': {
        'name': 'OpenCode CLI',
        'icon': '🔓',
        'desc': '开源 AI 编程助手命令行工具',
        'command': 'opencode',
        'color': 'orange',
        'category': 'cli'
    },
    "iflow": {
        'name': 'iFlow CLI',
        'icon': '🚀',
        'desc': 'iFlow AI 编程助手命令行工具',
        'command': 'iflow',
        'color': 'orange',
        'category': 'cli'
    },
    "kilo": {
        'name': 'Kilocode CLI',
        'icon': '⚡',
        'desc': 'Kilocode AI 编程助手命令行工具',
        'command': 'kilo',
        'color': 'orange',
        'category': 'cli'
    },
    "codex": {
        'name': 'Codex CLI',
        'icon': '🧑‍💻',
        'desc': 'OpenAI 官方 AI 编程助手命令行工具',
        'command': 'codex',
        'color': 'orange',
        'category': 'cli'
    },
    "cursor-cli": {
        'name': 'Cursor CLI',
        'icon': '🐭',
        'desc': 'Cursor AI 编程助手命令行工具',
        'command': 'agent',
        'color': 'orange',
        'category': 'cli'
    },
    'docker': {
        'name': 'Docker',
        'icon': '🐳',
        'desc': 'Docker 容器管理工具，需在终端使用 docker 命令行操作',
        'command': 'docker',
        'color': 'orange',
        'category': 'cli'
    }
}


def check_port(host, port, timeout=1):
    """Check if port is open"""
    if port is None:
        return False
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        result = sock.connect_ex((host, port))
        sock.close()
        return result == 0
    except Exception:
        return False


def check_command(cmd):
    """Check if a command is available"""
    try:
        import shutil
        return shutil.which(cmd) is not None
    except Exception:
        return False


def check_docker():
    """Check if Docker is available and connected"""
    try:
        import subprocess
        result = subprocess.run(
            ['docker', 'ps'],
            capture_output=True,
            timeout=5,
        )
        return result.returncode == 0
    except Exception:
        return False


def get_services_status():
    """Get all services status"""
    status = {}

    for service_id, service in SERVICES.items():
        # Docker 特殊处理：检测命令可用性而非端口
        if service_id == 'docker':
            is_running = check_docker()
        else:
            # 使用配置的检测地址检测服务状态
            check_host = service.get('check_host', HOST_CHECK)
            is_running = check_port(check_host, service['internal_port'])

        status[service_id] = {
            **service,
            'running': is_running,
            'port': service['external_port']  # 返回外部端口给前端显示
        }

    for tool_id, tool in CLI_TOOLS.items():
        # 检测命令是否可用
        is_running = check_command(tool.get('command', tool_id))
        status[tool_id] = {
            **tool,
            'running': is_running
        }

    return status


class DashboardHandler(http.server.SimpleHTTPRequestHandler):
    """Custom request handler"""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=BOARD_DIR, **kwargs)

    def do_GET(self):
        parsed = urlparse(self.path)

        if parsed.path == '/api/services':
            self.send_api_response()
            return

        if parsed.path.startswith('/api/check/'):
            service_id = parsed.path.replace('/api/check/', '')
            self.send_check_response(service_id)
            return

        super().do_GET()

    def send_api_response(self):
        """Send services status API response"""
        try:
            status = get_services_status()
            data = json.dumps(status, ensure_ascii=False)
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(data.encode('utf-8'))
        except Exception as e:
            self.send_error(500, str(e))

    def send_check_response(self, service_id):
        """Check single service status"""
        if service_id in SERVICES:
            service = SERVICES[service_id]
            # Docker 特殊处理
            if service_id == 'docker':
                is_running = check_docker()
            else:
                check_host = service.get('check_host', HOST_CHECK)
                is_running = check_port(check_host, service['internal_port'])
            response = {
                'id': service_id,
                'running': is_running,
                'internal_port': service['internal_port'],
                'external_port': service['external_port']
            }
            data = json.dumps(response)
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(data.encode('utf-8'))
        else:
            self.send_error(404, 'Service not found')

    def log_message(self, format, *args):
        """Custom log format"""
        print('[{}] {}'.format(self.log_date_time_string(), args[0]))


def main():
    """Main function"""
    print('Starting AgentBox Dashboard on port {}'.format(PORT))
    print('Serving files from: {}'.format(BOARD_DIR))

    server = http.server.HTTPServer(('0.0.0.0', PORT), DashboardHandler)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\nShutting down...')
        server.shutdown()


if __name__ == '__main__':
    main()