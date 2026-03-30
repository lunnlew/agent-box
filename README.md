# AgentBox

> 基于 Docker 的可插拔式 AI Agent 工具集成容器

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/your-org/agent-box)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

---

## 📋 目录

- [核心特性](#-核心特性)
- [快速开始](#-快速开始)
- [可用插件](#-可用插件)
- [服务管理](#-服务管理)
- [Web 服务访问](#-web-服务访问)
- [架构说明](#-架构说明)
- [配置参考](#-配置参考)
- [开发指南](#-开发指南)
- [故障排查](#-故障排查)

---

## 🚀 核心特性

### 插件化架构

| 特性 | 说明 |
|-----|------|
| **可插拔设计** | 通过 YAML 配置文件动态管理 16+ AI Agent 工具 |
| **完整生命周期** | 支持安装、卸载、更新、启动、停止、重启 |
| **依赖管理** | 自动处理插件依赖关系和启动顺序 |
| **容错启动** | 单个插件失败不影响其他插件和容器运行 |

### 数据持久化

| 类型 | 路径 | 说明 |
|-----|------|------|
| **工具包** | `/home/agent/tools` | npm/pip 全局包 |
| **工作目录** | `/home/agent/workspace` | 用户工作区 |
| **缓存** | `/home/agent/cache` | 模型缓存、临时文件 |
| **配置** | `/home/agent/.config` | 应用配置 |
| **日志** | `/home/agent/logs` | 服务日志 |

### 服务管理

- **Supervisor 守护进程** - 自动重启崩溃的服务
- **Web Dashboard** - 统一的服务入口面板
- **CLI 工具** - `agentbox` 命令管理所有插件
- **健康检查** - 实时监控服务状态

### 高级功能

| 功能 | 说明 |
|-----|------|
| **宿主机共享** | `host-share` 目录实现宿主机与容器间文件共享 |
| **Docker 支持** | 支持在容器内操作宿主机 Docker |
| **镜像加速** | 支持 NPM/PIP/Go/GitHub 等镜像源配置 |
| **安全隔离** | 非 root 用户运行，最小权限原则 |

---

## 🎯 快速开始

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

## 📦 可用插件

### CLI 工具 (8 个)

通过命令行使用，无需常驻服务。

| 插件 | 命令 | 描述 | API Key |
|-----|------|------|---------|
| **claude-code** | `claude` | Anthropic 官方 AI 编程助手 | `ANTHROPIC_API_KEY` |
| **cursor-cli** | `agent` | Cursor AI 编程助手 | - |
| **codex** | `codex` | OpenAI 官方 AI 编程助手 | `OPENAI_API_KEY` |
| **qwen-code** | `qwen` | 阿里云通义千问 AI 编程助手 | `DASHSCOPE_API_KEY` |
| **opencode** | `opencode` | 开源 AI 编程助手 | `OPENAI_API_KEY` |
| **kilocode** | `kilo` | Kilocode AI 编程助手 | `KILOCODE_API_KEY` |
| **iflow** | `iflow` | iFlow AI 编程助手 | `IFLOW_API_KEY` |
| **docker** | `docker` | Docker 容器管理工具 | - |

### Web 服务 (9 个)

通过浏览器访问，常驻后台服务。

| 插件 | 端口 | 访问地址 | 说明 |
|-----|------|----------|------|
| **board** | 8888 | http://localhost:8888 | Dashboard - 统一服务入口 |
| **vscode-server** | 8080 | http://localhost:8080 | 浏览器中的 VS Code IDE |
| **web-terminal** | 7681 | http://localhost:7681 | 浏览器终端服务 |
| **openclaw** | 18789 | http://localhost:18789 | 个人 AI 助手网关 |
| **copaw** | 8088 | http://localhost:8088 | AgentScope AI 助手网关 |
| **clawpanel** | 1420 | http://localhost:1420 | OpenClaw 可视化管理面板（非官方，纯 Web） |
| **openclaw-dashboard** | 7000 | http://localhost:7000 | OpenClaw 管理面板（非官方，纯 Web） |
| **clawport-ui** | 3000 | http://localhost:3000 | OpenClaw 可视化管理中心（非官方，纯 Web） |
| **skills-manager** | 6080 | http://localhost:6080/vnc.html | AI 技能管理工具 (VNC) |
| **openclaw-manager** | 6081 | http://localhost:6081/vnc.html | OpenClaw 桌面管理工具 (非官方，VNC) |
| **novnc-base** | - | - | noVNC 基础显示服务 |

### Docker 容器服务 (2 个)

| 插件 | 端口 | 说明 |
|-----|------|------|
| **hiclaw** | 18080/18001/18088 | HiClaw AI Agent 平台（独立 Docker 容器） |
| **deer-flow** | 2026 | DeerFlow Super Agent Harness (sub-agents, memory, sandbox) |

---

## 🔧 服务管理

### CLI 命令

```bash
# 进入容器
docker exec -it agentbox bash

# 查看帮助
agentbox help

# 列出所有插件
agentbox list

# 安装插件
agentbox install <plugin-name>
agentbox install <plugin-name> --force    # 强制重装

# 批量安装（容错模式）
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

### 服务控制

```bash
# 启动所有服务（容错模式）
agentbox start-all

# 单个服务管理
agentbox start <name>
agentbox stop <name>
agentbox restart <name>
agentbox ps <name>

# 查看所有服务状态
agentbox ps
```

### 镜像源配置

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

## 🌐 Web 服务访问

### Dashboard

**访问地址:** http://localhost:8888

Dashboard 提供：
- 📊 所有服务的统一入口界面
- ✅ 实时服务状态检测
- 🔗 快速访问各 Web 服务
- 📋 CLI 工具命令复制

### 直接访问地址

| 服务 | 地址 | 默认密码 | 说明 |
|-----|------|----------|------|
| **Dashboard** | http://localhost:8888 | - | 统一入口 |
| **VS Code Server** | http://localhost:8080 | `agentbox` | Web IDE |
| **Web Terminal** | http://localhost:7681 | - | 浏览器终端 |
| **OpenClaw** | http://localhost:18789 | - | AI 助手网关 |
| **CoPaw** | http://localhost:8088 | - | AgentScope 网关 |
| **ClawPanel** | http://localhost:1420 | - | OpenClaw 管理面板 |
| **OpenClaw Dashboard** | http://localhost:7000 | - | OpenClaw 管理面板 |
| **ClawPort UI** | http://localhost:3000 | - | OpenClaw 管理中心 |
| **Skills Manager** | http://localhost:6080/vnc.html | - | VNC 界面 |
| **OpenClaw Manager** | http://localhost:6081/vnc.html | - | VNC 界面 |
| **HiClaw Gateway** | http://localhost:18080 | - | Higress 网关 |
| **HiClaw Console** | http://localhost:18001 | - | 管理控制台 |
| **HiClaw Element** | http://localhost:18088 | - | Matrix 客户端 |
| **DeerFlow** | http://localhost:2026 | - | Super Agent Harness |

---

## 🏗️ 架构说明

### 目录结构

```
agent-box/
├── docker-compose.yml          # Docker 编排配置
├── Dockerfile                  # 镜像构建文件
├── .env.example                # 环境变量模板
├── config/
│   └── plugins.yaml            # 插件启用配置
├── scripts/
│   ├── entrypoint.sh           # 容器入口脚本（容错设计）
│   ├── lib.sh                  # 共享函数库
│   └── plugin-manager.sh       # 插件管理 CLI (agentbox)
├── plugins/                    # 插件定义目录 (18 个插件)
│   ├── board/                  # Dashboard 服务
│   ├── openclaw/               # OpenClaw 网关
│   ├── vscode-server/          # VS Code Server
│   ├── web-terminal/           # Web 终端
│   ├── skills-manager/         # 技能管理器
│   ├── openclaw-manager/       # OpenClaw 桌面管理工具
│   ├── novnc-base/             # noVNC 基础服务
│   ├── copaw/                  # CoPaw 网关
│   ├── hiclaw/                 # HiClaw AI Agent 平台
│   ├── deer-flow/              # DeerFlow Super Agent Harness
│   ├── claude-code/            # Claude Code CLI
│   ├── cursor-cli/             # Cursor CLI
│   ├── codex/                  # Codex CLI
│   ├── qwen-code/              # 通义千问 CLI
│   ├── opencode/               # OpenCode CLI
│   ├── kilocode/               # Kilocode CLI
│   ├── iflow/                  # iFlow CLI
│   ├── clawpanel/              # ClawPanel 管理面板
│   ├── openclaw-dashboard/     # OpenClaw Dashboard
│   ├── clawport-ui/            # ClawPort UI
│   └── docker/                 # Docker CLI
├── host-share/                 # 宿主机共享目录
└── data/                       # 持久化数据目录
```

### 启动流程（容错设计）

```
容器启动 (root)
    │
    ├── 初始化环境目录 ✅
    ├── 配置 Docker TCP 连接 ✅
    │
    └── 切换到 agent 用户 (gosu)
            │
            ├── 配置镜像源 (NPM/PIP/Go) ⚠️ 失败继续
            ├── 启动 Supervisor 守护进程 ⚠️ 失败继续
            ├── 恢复插件符号链接 ⚠️ 失败继续
            ├── 安装启用的插件 ⚠️ 失败继续
            └── 启动插件服务 ⚠️ 失败继续
                    │
                    └─→ 容器正常运行 ✅
                        └─→ 显示失败统计和重试建议
```

**关键特性:**
- ❌ 不使用 `set -e`，避免单个命令失败导致退出
- ✅ 所有关键步骤使用 `|| true` 容错
- ✅ 记录成功/失败统计
- ✅ 提供重试建议
- ✅ 单个插件失败不影响容器和其他插件

### 持久化映射

| 容器路径 | 宿主机路径 | 用途 |
|---------|-----------|------|
| `/home/agent/tools` | `./data/tools` | npm/pip 全局包 |
| `/home/agent/workspace` | `./data/workspace` | 工作目录 |
| `/home/agent/cache` | `./data/cache` | 模型缓存、临时文件 |
| `/home/agent/.config` | `./data/.config` | 配置文件 |
| `/home/agent/logs` | `./data/logs` | 服务日志 |
| `/host-share` | `./host-share` | 宿主机共享目录 |

---

## ⚙️ 配置参考

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
# 格式：${环境变量:-默认值}，可通过 .env 文件自定义
BOARD_PORT=8888
VSCODE_PORT=8080
WEB_TERMINAL_PORT=7681
OPENCLAW_PORT=18789
COPAW_PORT=8088
NOVNC_PORT=6080
HICLAW_PORT_GATEWAY=18080
HICLAW_PORT_CONSOLE=18001
HICLAW_PORT_ELEMENT_WEB=18088
DASHBOARD_PORT=7000       # OpenClaw Dashboard
CLAWPORT_PORT=3000        # ClawPort UI
CLAWPANEL_PORT=1420       # ClawPanel
SKILLS_MANAGER_NOVNC_PORT=6080
OPENCLAW_MANAGER_NOVNC_PORT=6081
DEERFLOW_PORT=2026        # DeerFlow Gateway
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

# 插件依赖（可选）
depends:
  - novnc-base

# 安装命令（支持多行）
install:
  - |
    set -e
    npm uninstall -g my-cli 2>/dev/null || true
    npm install -g my-cli
    # 验证安装
    command -v my-cli || exit 1

# 环境变量
env:
  MY_API_KEY: required              # 必需变量
  MY_OPTIONAL: optional             # 可选变量
  PATH_APPEND: ~/.my-plugin/bin     # 添加到 PATH
  MY_CONFIG: export MY_CONFIG="..." # 设置变量

# 安装后执行
post_install:
  - mkdir -p ~/.my-plugin

# 持久化目录（自动隔离）
volumes:
  - ~/.my-plugin: 插件数据

# 健康检查
healthcheck:
  command: my-cli --version

# 服务配置（可选）
service:
  # 常驻服务类型
  daemon: true
  # 自动启动
  auto_start: true
  # 崩溃重启
  restart: true
  # 最大重启次数
  max_restarts: 5
  # 启动命令
  command: my-cli server
  # 停止命令
  stop_command: pkill -f "my-cli"
  # 重启命令
  restart_command: pkill -f "my-cli"; sleep 2; my-cli server

# 卸载命令（保护用户数据）
uninstall:
  - |
    set -e
    # 清理安装文件
    npm uninstall -g my-cli
    rm -rf ~/.my-plugin/bin
    # ✅ 保留用户数据
    # rm -rf ~/.my-plugin  # 不要删除
    log_info "User data preserved"

# 更新命令
update:
  - npm update -g my-cli
```

---

## 🛠️ 开发指南

### 添加新插件

1. **创建插件目录**

```bash
mkdir plugins/my-plugin
```

2. **创建 plugin.yaml**

参考上方配置格式，确保包含：
- ✅ `install` - 安装命令
- ✅ `uninstall` - 卸载命令（保护用户数据）
- ✅ `update` - 更新命令
- ✅ `healthcheck` - 健康检查
- ✅ `service` - 服务配置（如果是 Web 服务）
- ✅ `volumes` - 持久化目录

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
  daemon: true               # 常驻服务，使用 Supervisor
  auto_start: true           # 自动启动
  command: my-cli server     # 启动命令
  stop_command: pkill -f "my-cli"
  restart_command: pkill -f "my-cli"; sleep 2; my-cli server
  restart: true              # 自动重启
  max_restarts: 5            # 最大重启次数
```

服务会被 Supervisor 管理，日志输出到 `~/logs/<plugin-name>.log`。

### Dashboard 集成

服务自动出现在 Dashboard 中，支持：
- 🌐 Web 服务：显示 URL 和端口
- 💻 CLI 工具：显示命令行
- ✅ 状态实时检测

---

## 🔍 故障排查

### 插件安装失败

```bash
# 查看详细日志
docker exec agentbox agentbox install <plugin> --force

# 检查依赖
docker exec agentbox agentbox status

# 手动重试
docker exec -it agentbox bash
agentbox install <plugin>
```

### 服务无法启动

```bash
# 查看服务日志
docker exec agentbox tail -f ~/logs/<service>.log

# 查看 Supervisor 状态
docker exec agentbox supervisorctl -c ~/supervisor/supervisord.conf status

# 手动启动服务
docker exec agentbox agentbox start <service>
```

### 容器重启问题

**问题:** 单个插件失败导致容器重启

**解决:** 已优化为容错模式

```bash
# 查看启动日志
docker logs agentbox | grep -E "(Failed|WARNING|summary)"

# 查看失败统计
docker logs agentbox | grep "summary"

# 手动重试失败插件
docker exec -it agentbox bash
agentbox install-all
agentbox start-all
```

### 查看服务状态

```bash
# 所有服务状态
docker exec agentbox agentbox service-status

# Supervisor 状态
docker exec agentbox supervisorctl -c ~/supervisor/supervisord.conf status

# 实时日志
docker exec agentbox tail -f ~/logs/<service>.log
```

---

## 📊 常用操作

### 容器管理

```bash
# 启动
docker-compose up -d

# 停止
docker-compose down

# 重启
docker-compose restart

# 查看日志
docker-compose logs -f

# 重建容器
docker-compose down && docker-compose up -d --build

# 进入容器
docker exec -it agentbox bash

# 查看资源
docker stats agentbox

# 清理构建缓存
docker builder prune -f
```

### 插件管理

```bash
# 安装所有启用的插件
agentbox install-all

# 启动所有服务
agentbox start-start-all

# 查看系统状态
agentbox status

# 查看镜像源配置
agentbox mirrors
```

---

## 📝 许可证

MIT

---

**最后更新:** 2026-03-23
**版本:** 1.1.2
**插件数量:** 20 (CLI 工具 8 个 + Web 服务 10 个 + Docker 容器 2 个)
