# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AgentBox is a Docker-based, plugin-driven AI Agent integration container that dynamically manages 20+ AI Agent tools through YAML configuration. The project provides a fault-tolerant orchestration system where individual plugin failures do not crash the container.

## Architecture

### Core Components

```
agent-box/
├── docker-compose.yml      # Docker orchestration with 13+ port mappings
├── Dockerfile              # Ubuntu 22.04 base with Node.js 22, Python, Supervisor
├── .env / .env.example     # API keys and mirror configuration
├── config/
│   └── plugins.yaml        # Plugin enable/disable configuration
├── scripts/
│   ├── entrypoint.sh       # Container entrypoint (fault-tolerant init)
│   ├── lib.sh              # Shared bash functions (logging, YAML parsing)
│   └── plugin-manager.sh   # CLI tool: `agentbox` command
├── plugins/                # 23 plugin definitions (YAML)
│   ├── claude-code/        # Anthropic Claude Code CLI
│   ├── deer-flow/          # DeerFlow Super Agent Harness (Docker)
│   ├── hiclaw/             # HiClaw AI Agent Platform (Docker)
│   ├── vscode-server/      # Web IDE (code-server)
│   ├── board/              # Dashboard (unified entry point)
│   └── ...                 # 18 more plugins
├── host-share/             # Host-container file sharing
└── data/                   # Persistent volumes (tools, workspace, logs)
```

### Plugin System

Plugins are defined in `plugins/*/plugin.yaml` with the following structure:

- **name/version/description** - Basic metadata
- **requires** - Dependencies (docker, bash, python3, etc.)
- **install** - Installation commands (bash script)
- **env** - Environment variables (required/optional)
- **volumes** - Persistent directories
- **service** - Daemon configuration (Supervisor-managed)
- **healthcheck** - Health check command
- **uninstall/update** - Lifecycle management

### Service Management

Services are managed by **Supervisor** with automatic restart on failure:

- **daemon: true** - Supervisor-managed service
- **auto_start: true** - Start on container boot
- **restart: true** - Auto-restart on crash
- **max_restarts** - Restart limit

### Fault-Tolerant Design

The entrypoint script (`entrypoint.sh`) uses explicit error handling:

- No `set -e` - commands don't exit on failure
- `|| true` pattern for non-critical operations
- Success/failure statistics logging
- Individual plugin failures don't affect others

## Commands

### Container Management

```bash
# Build and start
docker-compose build
docker-compose up -d

# View logs
docker-compose logs -f
docker logs agentbox | grep -E "(Failed|WARNING|summary)"

# Enter container
docker exec -it agentbox bash

# Rebuild
docker-compose down && docker-compose up -d --build
```

### Plugin Management (inside container)

```bash
# List plugins
agentbox list

# Install/reinstall
agentbox install <plugin-name>
agentbox install <plugin-name> --force    # Force reinstall

# Install all enabled plugins
agentbox install-all
agentbox install-all --force

# Uninstall
agentbox uninstall <plugin-name>

# Update
agentbox update <plugin-name>

# Enable/disable in config
agentbox enable <plugin-name>
agentbox disable <plugin-name>
```

### Service Management (inside container)

```bash
# Start/stop/restart all services
agentbox start-all
agentbox stop-all

# Individual service control
agentbox start <name>
agentbox stop <name>
agentbox restart <name>
agentbox ps <name>

# View all service status
agentbox ps

# Supervisor direct control
supervisorctl -c ~/supervisor/supervisord.conf status
supervisorctl -c ~/supervisor/supervisord.conf stop <service>
supervisorctl -c ~/supervisor/supervisord.conf restart <service>
```

### Mirror Configuration

```bash
# View current mirrors
agentbox mirrors

# Set mirrors
agentbox set-mirror npm https://registry.npmmirror.com
agentbox set-mirror pip https://mirrors.aliyun.com/pypi/simple/
agentbox set-mirror go https://goproxy.cn,direct
```

## Development Workflow

### Adding a New Plugin

1. **Create plugin directory**: `mkdir plugins/my-plugin`

2. **Create plugin.yaml** with required fields:
   - `install` - Installation script
   - `uninstall` - Cleanup script (preserve user data)
   - `update` - Update script
   - `healthcheck` - Health check command
   - `service` - Service config (if web service)
   - `volumes` - Persistent directories

3. **Enable in config**: Edit `config/plugins.yaml`

4. **Test installation**:
   ```bash
   docker exec -it agentbox agentbox install my-plugin
   ```

### Key Files to Understand

| File | Purpose |
|------|---------|
| `scripts/lib.sh` | Shared functions: logging, YAML parsing, mirror config |
| `scripts/entrypoint.sh` | Container bootstrap with fault tolerance |
| `scripts/plugin-manager.sh` | `agentbox` CLI implementation |
| `config/plugins.yaml` | Plugin enable/disable list |
| `plugins/*/plugin.yaml` | Individual plugin definitions |

### Plugin Types

**CLI Tools** (8 plugins): claude-code, cursor-cli, codex, qwen-code, opencode, kilocode, iflow, docker
- No常驻 service
- Installed to `~/tools`
- Accessed via command line

**Web Services** (10 plugins): board, vscode-server, web-terminal, openclaw, copaw, clawpanel, openclaw-dashboard, clawport-ui, skills-manager, openclaw-manager
- Supervisor-managed daemons
- Port mappings in docker-compose.yml
- Accessed via browser

**Docker Container Services** (2 plugins): hiclaw, deer-flow
- Run as separate Docker containers
- Use `make` commands for lifecycle management

## Web Services

| Service | Port | URL | Default Password |
|---------|------|-----|------------------|
| Dashboard | 8888 | http://localhost:8888 | - |
| VS Code Server | 8080 | http://localhost:8080 | agentbox |
| Web Terminal | 7681 | http://localhost:7681 | - |
| OpenClaw | 18789 | http://localhost:18789 | - |
| CoPaw | 8088 | http://localhost:8088 | - |
| ClawPanel | 1420 | http://localhost:1420 | - |
| OpenClaw Dashboard | 7000 | http://localhost:7000 | - |
| ClawPort UI | 3000 | http://localhost:3000 | - |
| Skills Manager | 6080 | http://localhost:6080/vnc.html | - |
| OpenClaw Manager | 6081 | http://localhost:6081/vnc.html | - |
| HiClaw Gateway | 18080 | http://localhost:18080 | - |
| HiClaw Console | 18001 | http://localhost:18001 | - |
| DeerFlow | 2026 | http://localhost:2026 | - |

## Environment Variables

Required API keys (configure in `.env`):

- `ANTHROPIC_API_KEY` - Claude Code
- `DASHSCOPE_API_KEY` - Qwen Code / DeerFlow / HiClaw
- `OPENAI_API_KEY` - OpenCode / Codex
- `KILOCODE_API_KEY` - Kilocode
- `IFLOW_API_KEY` - iFlow

Mirror configuration:

- `NPM_REGISTRY` - NPM mirror
- `PIP_INDEX_URL` - PyPI mirror
- `GOPROXY` - Go module proxy
- `GITHUB_PROXY` - GitHub proxy

Transparent proxy (for network acceleration):

- `TRANSPARENT_PROXY_ENABLED` - Enable transparent proxy (default: false)
- `TRANSPARENT_PROXY_ADDR` - Proxy server address (default: 127.0.0.1:1080)
- `TRANSPARENT_PROXY_PORTS` - Ports to intercept (default: 80,443)

The transparent proxy uses redsocks + iptables to automatically redirect TCP traffic
through a SOCKS5/HTTP proxy. This is useful for:
- Intercepting traffic from third-party tools that don't support proxy settings
- Bypassing network restrictions in restricted environments
- Accelerating downloads from slow/blocked sources

Note: Requires `NET_ADMIN` capability (already configured in docker-compose.yml).

## Troubleshooting

### Plugin Installation Failed

```bash
# Check logs
docker exec agentbox agentbox install <plugin> --force

# Check dependencies
agentbox status

# Manual retry inside container
docker exec -it agentbox bash
agentbox install <plugin>
```

### Service Won't Start

```bash
# View service logs
docker exec agentbox tail -f ~/logs/<service>.log

# Check Supervisor status
docker exec agentbox supervisorctl -c ~/supervisor/supervisord.conf status

# Manual start
docker exec agentbox agentbox start <service>
```

### Permission Issues

The container runs as `agent` user (UID 1000) with `docker` group:
- Docker socket permissions are fixed at startup
- Plugin volumes use symlinks for isolation
- Shared functions handle permission fixes in install scripts

## Testing

No formal test suite. Testing is done by:
1. Building and running the container
2. Installing plugins via `agentbox install`
3. Verifying services start and respond

For plugin development, test inside a running container:
```bash
docker exec -it agentbox bash
cd ~/plugins-config/my-plugin
# Test install script manually
```
