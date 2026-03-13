# AgentBox

> 基于 Docker 的可插拔式 AI Agent 工具集成容器

## 目录

- [功能特性](#功能特性)
- [快速开始](#快速开始)
- [核心架构](#核心架构)
- [插件管理](#插件管理)
- [可用插件](#可用插件)
- [Web 服务](#web-服务)
- [Docker 支持](#docker-支持)
- [配置参考](#配置参考)
- [开发指南](#开发指南)

---

## 功能特性

| 特性 | 描述 |
|-----|------|
| **可插拔架构** | 通过 YAML 配置文件动态管理 AI Agent 工具 |
| **完整持久化** | 数据、工具包、工作目录、缓存全部持久化存储 |
| **服务管理** | 内置 Supervisor 管理后台服务进程 |
| **CLI 工具** | 提供 `agentbox` 命令管理插件的安装、卸载、更新 |
| **镜像加速** | 支持 NPM/PIP/Go/GitHub 等镜像源配置 |
| **Docker 支持** | 支持在容器内操作宿主机 Docker |
| **实时状态** | Dashboard 实时检测服务运行状态 |
| **安全隔离** | 非 root 用户运行，最小权限原则 |

---

## 快速开始

### 1. 环境准备

```bash
# 克隆项目
git clone <repo-url>
cd agent-box

# 复制环境变量配置
cp .env.example .env

# 编辑配置文件，填写 API Key
vim .env
```

### 2. 构建和启动

```bash
# 构建镜像
docker-compose build

# 启动容器
docker-compose up -d

# 查看启动日志
docker-compose logs -f
```

### 3. 访问服务

```bash
# 浏览器访问 Dashboard (默认端口 8888)
http://localhost:8888

# 或进入容器
docker exec -it agentbox bash
```

---

## 核心架构

### 目录结构

```
agent-box/
├── docker-compose.yml          # Docker 编排配置
├── Dockerfile                  # 镜像构建文件
├── .env.example                # 环境变量模板
├── config/
│   └── plugins.yaml            # 插件启用配置
├── scripts/
│   ├── entrypoint.sh           # 容器入口脚本
│   └── plugin-manager.sh       # 插件管理 CLI (agentbox)
├── plugins/                    # 插件定义目录
│   ├── board/                  # Dashboard 服务
│   ├── claude-code/            # Claude Code CLI
│   ├── qwen-code/              # 通义千问 CLI
│   ├── opencode/               # OpenCode CLI
│   ├── iflow/                  # iFlow CLI
│   ├── openclaw/               # OpenClaw 网关
│   ├── vscode-server/          # VS Code Server
│   ├── web-terminal/           # Web 终端
│   ├── skills-manager/         # 技能管理器
│   ├── novnc-base/             # noVNC 基础服务
│   ├── kilocode/               # Kilocode CLI
│   ├── cursor-cli/             # Cursor CLI
│   ├── codex/                  # Codex CLI
│   ├── copaw/                  # CoPaw 网关
│   └── docker/                 # Docker CLI
└── data/                       # 持久化数据目录
    ├── tools/                  # 工具包
    ├── workspace/              # 工作目录
    ├── cache/                  # 缓存文件
    ├── logs/                   # 服务日志
    └── plugins-data/           # 插件隔离数据
```

### 启动流程

```
容器启动 (root)
    │
    ├── 初始化环境目录
    ├── 配置 Docker TCP 连接
    │
    └── 切换到 agent 用户 (gosu)
            │
            ├── 配置镜像源 (NPM/PIP/Go)
            ├── 启动 Supervisor 守护进程
            ├── 恢复插件符号链接
            ├── 安装启用的插件
            └── 启动插件服务
```

### 持久化映射

| 容器路径 | 用途 |
|---------|------|
| `/home/agent/tools` | npm/pip 全局包 |
| `/home/agent/workspace` | 工作目录 |
| `/home/agent/cache` | 模型缓存、临时文件 |
| `/home/agent/.config` | 配置文件 |
| `/home/agent/logs` | 服务日志 |
| `/home/agent/plugins-data` | 插件隔离数据 |

---

## 插件管理

### CLI 命令

```bash
# 查看帮助
agentbox help

# 列出所有插件
agentbox list

# 安装插件
agentbox install <plugin-name>
agentbox install <plugin-name> --force    # 强制重装

# 批量安装
agentbox install-all
agentbox install-all --force

# 卸载插件
agentbox uninstall <plugin-name>

# 更新插件
agentbox update <plugin-name>

# 查看系统状态
agentbox status

# 恢复符号链接
agentbox restore-links
```

### 服务管理

```bash
# 启动所有服务
agentbox start-services

# 单个服务管理
agentbox start-service <name>
agentbox stop-service <name>
agentbox restart-service <name>
agentbox service-status <name>

# 查看所有服务状态
agentbox service-status
```

### 镜像源管理

```bash
# 查看当前配置
agentbox mirrors

# 设置镜像源
agentbox set-mirror npm https://registry.npmmirror.com
agentbox set-mirror pip https://mirrors.aliyun.com/pypi/simple/
agentbox set-mirror go https://goproxy.cn,direct
agentbox set-mirror github https://mirror.ghproxy.com/
```

---

## 可用插件

### CLI 工具 (命令行使用)

| 插件 | 命令 | 描述 | API Key |
|-----|------|------|---------|
| claude-code | `claude` | Anthropic 官方 AI 编程助手 | `ANTHROPIC_API_KEY` |
| qwen-code | `qwen` | 阿里云通义千问 AI 编程助手 | `DASHSCOPE_API_KEY` |
| opencode | `opencode` | 开源 AI 编程助手 | `OPENAI_API_KEY` |
| iflow | `iflow` | iFlow AI 编程助手 | `IFLOW_API_KEY` |
| kilocode | `kilo` | Kilocode AI 编程助手 | `KILOCODE_API_KEY` |
| cursor-cli | `agent` | Cursor AI 编程助手 | - |
| codex | `codex` | OpenAI 官方 AI 编程助手 | `OPENAI_API_KEY` |
| docker | `docker` | Docker 容器管理工具 | - |

### Web 服务 (浏览器访问)

| 插件 | 端口 | 容器内端口 | 描述 |
|-----|------|------------|------|
| board | ${BOARD_PORT:-8888} | 8888 | Dashboard - 统一服务入口面板 |
| vscode-server | ${VSCODE_PORT:-8080} | 8080 | 浏览器中的 VS Code IDE |
| web-terminal | ${WEB_TERMINAL_PORT:-7681} | 7681 | 浏览器终端服务 |
| openclaw | ${OPENCLAW_PORT:-18789} | 18789 | 个人 AI 助手网关 |
| copaw | ${COPAW_PORT:-8088} | 8088 | AgentScope AI 助手网关 |
| skills-manager | ${NOVNC_PORT:-6080} | 6080 | AI 技能管理工具 (VNC) |
| hiclaw-gateway | ${HICLAW_GATEWAY_PORT:-18080} | 8080 | HiClaw Higress 网关 |
| hiclaw-console | ${HICLAW_CONSOLE_PORT:-18001} | 8001 | HiClaw 管理控制台 |
| hiclaw-element | ${HICLAW_ELEMENT_PORT:-18088} | 8088 | HiClaw Matrix 消息客户端 |

### 基础服务

| 插件 | 描述 |
|-----|------|
| novnc-base | noVNC 基础服务，提供虚拟显示环境 |

---

## Web 服务

### Dashboard

访问地址: **http://localhost:${BOARD_PORT:-8888}** (默认 8888)

Dashboard 提供：
- 所有服务的统一入口界面
- 实时服务状态检测
- 快速访问各 Web 服务
- CLI 工具命令复制

### 服务状态检测

| 服务类型 | 检测方式 |
|---------|---------|
| Web 服务 | TCP 端口连接检测 |
| CLI 工具 | `shutil.which()` 命令查找 |
| Docker | 执行 `docker ps` 命令 |

### 直接访问

| 服务 | 地址 | 说明 |
|-----|------|------|
| VS Code Server | http://localhost:${VSCODE_PORT:-8080} | 密码: `agentbox` |
| Web Terminal | http://localhost:${WEB_TERMINAL_PORT:-7681} | 浏览器终端 |
| OpenClaw Gateway | http://localhost:${OPENCLAW_PORT:-18789} | AI 助手网关 |
| CoPaw Gateway | http://localhost:${COPAW_PORT:-8088} | AgentScope 网关 |
| Skills Manager | http://localhost:${NOVNC_PORT:-6080}/vnc.html | VNC 界面 |
| HiClaw Gateway | http://localhost:${HICLAW_GATEWAY_PORT:-18080} | Higress 网关 |
| HiClaw Console | http://localhost:${HICLAW_CONSOLE_PORT:-18001} | 管理控制台 |
| HiClaw Element | http://localhost:${HICLAW_ELEMENT_PORT:-18088} | Matrix 客户端 |

---

### 使用方式

```bash
# 进入容器
docker exec -it agentbox bash

# 加载环境变量
source ~/.bashrc

# Docker 命令
docker ps
docker images
docker run hello-world
```

---

## 配置参考

### 环境变量 (.env)

```bash
# ========== API Keys ==========
ANTHROPIC_API_KEY=your-key        # Claude Code
DASHSCOPE_API_KEY=your-key        # Qwen Code
OPENAI_API_KEY=your-key           # OpenCode/Codex
KILOCODE_API_KEY=your-key         # Kilocode
IFLOW_API_KEY=your-key            # iFlow

# ========== 镜像源 ==========
NPM_REGISTRY=https://registry.npmmirror.com
PIP_INDEX_URL=https://mirrors.aliyun.com/pypi/simple/
GOPROXY=https://goproxy.cn,direct
GITHUB_PROXY=https://mirror.ghproxy.com/

# ========== 代理 ==========
HTTP_PROXY=
HTTPS_PROXY=
INSTALL_PROXY=

# ========== 端口配置 ==========
# 格式: ${环境变量:-默认值}，可通过 .env 文件自定义
BOARD_PORT=8888
VSCODE_PORT=8080
WEB_TERMINAL_PORT=7681
OPENCLAW_PORT=18789
COPAW_PORT=8088
NOVNC_PORT=6080
HICLAW_GATEWAY_PORT=18080
HICLAW_CONSOLE_PORT=18001
HICLAW_ELEMENT_PORT=18088
```

### 插件配置 (plugin.yaml)

```yaml
# 基本信息
name: my-plugin
version: "1.0.0"
description: 插件描述

# 依赖要求
requires:
  - nodejs >= 18
  - npm

# 安装命令
install:
  - npm install -g my-cli

# 环境变量
env:
  MY_API_KEY: required              # 必需变量
  MY_OPTIONAL: optional             # 可选变量
  PATH_APPEND: ~/.my-plugin/bin     # 添加到 PATH
  MY_CONFIG: export MY_CONFIG="..." # 设置变量

# 安装后执行
post_install:
  - mkdir -p ~/.my-plugin

# 持久化目录
volumes:
  - ~/.my-plugin: 插件数据

# 健康检查
healthcheck:
  command: my-cli --version

# 服务配置 (可选)
service:
  auto_start: true
  command: my-cli server
  restart: true
  max_restarts: 5

# 卸载命令
uninstall:
  - npm uninstall -g my-cli
  - rm -rf ~/.my-plugin

# 更新命令
update:
  - npm update -g my-cli
```

### 环境变量格式

| 格式 | 说明 | 示例 |
|-----|------|------|
| `VAR: required` | 必需变量，安装时检查 | `ANTHROPIC_API_KEY: required` |
| `VAR: optional` | 可选变量 | `DEBUG: optional` |
| `VAR: export ...` | 设置变量并写入 .bashrc | `PATH: export PATH="..."` |
| `PATH_APPEND: path` | 添加到 PATH（防重复） | `PATH_APPEND: ~/.local/bin` |

---

## 开发指南

### 添加新插件

1. **创建插件目录**

```bash
mkdir plugins/my-plugin
```

2. **创建 plugin.yaml**

参考上方配置格式。

3. **启用插件**

编辑 `config/plugins.yaml`:

```yaml
plugins:
  - name: my-plugin
    enabled: true
```

4. **测试安装**

```bash
docker exec -it agentbox agentbox install my-plugin
```

### 服务开发

插件可提供后台服务：

```yaml
service:
  auto_start: true           # 自动启动
  command: my-cli server     # 启动命令
  restart: true              # 自动重启
  max_restarts: 5            # 最大重启次数
```

服务会被 Supervisor 管理，日志输出到 `~/logs/<plugin-name>.log`。

### Dashboard 集成

服务自动出现在 Dashboard 中，支持：
- 端口服务：显示 URL 和端口
- CLI 工具：显示命令行
- 状态实时检测

---

## 常用操作

```bash
# 容器管理
docker-compose up -d              # 启动
docker-compose down               # 停止
docker-compose restart            # 重启
docker-compose logs -f            # 查看日志

# 重建容器
docker-compose down && docker-compose up -d --build

# 进入容器
docker exec -it agentbox bash

# 查看资源
docker stats agentbox

# 清理构建缓存
docker builder prune -f
```

---

## 故障排除

### 插件安装失败

```bash
# 查看详细日志
docker exec agentbox agentbox install <plugin> --force

# 检查依赖
docker exec agentbox agentbox status
```

### 服务无法启动

```bash
# 查看服务日志
docker exec agentbox tail -f ~/logs/<service>.log

# 查看 Supervisor 状态
docker exec agentbox supervisorctl -c ~/supervisor/supervisord.conf status
```

---

## 许可证

MIT