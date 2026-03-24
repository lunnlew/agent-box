#!/usr/bin/env python3
import os
import re

# Get the DeerFlow root directory from environment
deer_flow_root = os.environ.get('DEER_FLOW_ROOT', '')

# Define path replacements - ordered from most specific to least specific
# This ensures volume mounts are replaced before generic paths
replacements = {
    # Handle nginx port - replace host port with DEERFLOW_PORT environment variable
    r'"2026:2026"': f'"{os.environ.get("DEERFLOW_PORT", "2026")}:2026"',

    # Handle ${DEER_FLOW_ROOT} environment variable references in environment section
    r'\$\{DEER_FLOW_ROOT\}/skills': f'{deer_flow_root}/skills',
    r'\$\{DEER_FLOW_ROOT\}/backend/\.deer-flow/threads': f'{deer_flow_root}/backend/.deer-flow/threads',
    r'\$\{DEER_FLOW_ROOT\}/backend/\.deer-flow': f'{deer_flow_root}/backend/.deer-flow',

    # Handle nginx config path
    r'\./nginx/\$\{NGINX_CONF:-nginx\.conf\}': f'{deer_flow_root}/docker/nginx/${{NGINX_CONF:-nginx.conf}}',

    # Handle volumes - convert to Windows paths (must come before generic path replacements)
    r'- \.\./frontend/src:/app/frontend/src': f'- {os.environ.get("DEER_FLOW_FRONTEND_SRC", "../frontend/src")}:/app/frontend/src',
    r'- \.\./frontend/public:/app/frontend/public': f'- {os.environ.get("DEER_FLOW_FRONTEND_PUBLIC", "../frontend/public")}:/app/frontend/public',
    r'- \.\./frontend/next\.config\.js:/app/frontend/next\.config\.js:ro': f'- {os.environ.get("DEER_FLOW_FRONTEND_NEXT_CONFIG", "../frontend/next.config.js")}:/app/frontend/next.config.js:ro',
    r'- \.\./logs:/app/logs': f'- {os.environ.get("DEER_FLOW_LOGS", "../logs")}:/app/logs',
    r'- \.\./config\.yaml:/app/config\.yaml': f'- {os.environ.get("DEER_FLOW_CONFIG_PATH", "../config.yaml")}:/app/config.yaml',
    r'- \.\./extensions_config\.json:/app/extensions_config\.json': f'- {os.environ.get("DEER_FLOW_EXTENSIONS_CONFIG_PATH", "../extensions_config.json")}:/app/extensions_config.json',
    r'- \.\./skills:/app/skills': f'- {os.environ.get("DEER_FLOW_SKILLS", "../skills")}:/app/skills',
    r'- \.\./backend/:/app/backend/': f'- {os.environ.get("DEER_FLOW_BACKEND", "../backend/")}:/app/backend/',

    # Generic path replacements (least specific, runs last)
    r'\.\./frontend/src': os.environ.get('DEER_FLOW_FRONTEND_SRC', '../frontend/src'),
    r'\.\./frontend/public': os.environ.get('DEER_FLOW_FRONTEND_PUBLIC', '../frontend/public'),
    r'\.\./frontend/next\.config\.js': os.environ.get('DEER_FLOW_FRONTEND_NEXT_CONFIG', '../frontend/next.config.js'),
    r'\.\./logs': os.environ.get('DEER_FLOW_LOGS', '../logs'),
    r'\.\./backend/': os.environ.get('DEER_FLOW_BACKEND', '../backend/'),
    r'\.\./config\.yaml': os.environ.get('DEER_FLOW_CONFIG_PATH', '../config.yaml'),
    r'\.\./extensions_config\.json': os.environ.get('DEER_FLOW_EXTENSIONS_CONFIG_PATH', '../extensions_config.json'),
    r'\.\./skills': os.environ.get('DEER_FLOW_SKILLS', '../skills'),
}

with open('docker-compose-dev.yaml', 'r') as f:
    content = f.read()

# Replace relative paths with absolute Windows paths
for pattern, replacement in replacements.items():
    content = re.sub(pattern, replacement, content)

with open('docker-compose-dev-modified.yaml', 'w') as f:
    f.write(content)

print('Modified docker-compose-dev-modified.yaml created')
print(f'DEER_FLOW_ROOT = {os.environ.get("DEER_FLOW_ROOT", "not set")}')
