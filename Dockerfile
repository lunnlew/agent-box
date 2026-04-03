# AgentBox Dockerfile
# 基于 ubuntu:24.04 的可插拔 AI Agent 工具集成容器

FROM ubuntu:24.04

# 构建参数 - 镜像源配置
# 默认使用国内镜像源加速下载
ARG NPM_REGISTRY=https://registry.npmmirror.com
ARG PIP_INDEX_URL=https://mirrors.aliyun.com/pypi/simple/
ARG PIP_TRUSTED_HOST=mirrors.aliyun.com
ARG UBUNTU_MIRROR=aliyun
ARG GITHUB_PROXY=
ARG GOPROXY=https://goproxy.cn,direct

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai
ENV HOME=/home/agent
ENV PATH="/home/agent/tools/bin:/root/.cargo/bin:/root/.local/bin:${PATH}"
ENV NPM_CONFIG_PREFIX="/home/agent/tools"
ENV PIP_USER=true
ENV PYTHONUSERBASE="/home/agent/tools"

# 镜像源环境变量 (运行时可覆盖)
ENV NPM_REGISTRY=${NPM_REGISTRY}
ENV PIP_INDEX_URL=${PIP_INDEX_URL}
ENV PIP_TRUSTED_HOST=${PIP_TRUSTED_HOST}
ENV GITHUB_PROXY=${GITHUB_PROXY}
ENV GOPROXY=${GOPROXY}

# 配置 Ubuntu APT 镜像源 (兼容 Ubuntu 22.04 和 24.04)
# Ubuntu 24.04 使用 DEB822 格式: /etc/apt/sources.list.d/ubuntu.sources
# Ubuntu 22.04 使用传统格式: /etc/apt/sources.list
RUN if [ -n "$UBUNTU_MIRROR" ]; then \
        case "$UBUNTU_MIRROR" in \
            aliyun) MIRROR_URL="mirrors.aliyun.com" ;; \
            tsinghua) MIRROR_URL="mirrors.tuna.tsinghua.edu.cn" ;; \
            ustc) MIRROR_URL="mirrors.ustc.edu.cn" ;; \
            163) MIRROR_URL="mirrors.163.com" ;; \
            tencent) MIRROR_URL="mirrors.cloud.tencent.com" ;; \
            huawei) MIRROR_URL="mirrors.huaweicloud.com" ;; \
            *) MIRROR_URL="$UBUNTU_MIRROR" ;; \
        esac && \
        # Ubuntu 24.04 DEB822 格式
        if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then \
            sed -i "s@archive.ubuntu.com@${MIRROR_URL}@g" /etc/apt/sources.list.d/ubuntu.sources && \
            sed -i "s@security.ubuntu.com@${MIRROR_URL}@g" /etc/apt/sources.list.d/ubuntu.sources; \
        fi && \
        # Ubuntu 22.04 传统格式 (兼容)
        if [ -f /etc/apt/sources.list ]; then \
            sed -i "s@archive.ubuntu.com@${MIRROR_URL}@g" /etc/apt/sources.list && \
            sed -i "s@security.ubuntu.com@${MIRROR_URL}@g" /etc/apt/sources.list; \
        fi; \
    fi

# 先安装基础工具 (curl, gpg 等)，用于后续 GPG 密钥导入
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    gnupg \
    ca-certificates \
    # 清理缓存
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# 下载并导入 GPG 密钥 (提前执行，避免后续安装失败)
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/setup_24.x | bash - && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    # 已安装：curl, wget, git, gnupg, ca-certificates
    # 基础工具
    sudo \
    # Python 环境 (Ubuntu 24.04 默认 Python 3.12)
    python3 \
    python3-pip \
    python3-venv \
    # Supervisor 进程管理
    supervisor \
    # GUI 支持 (noVNC)
    xvfb \
    x11vnc \
    python3-novnc \
    websockify \
    libgtk-3-0 \
    libnotify4 \
    libnss3 \
    libxss1 \
    libxtst6 \
    xdg-utils \
    libatspi2.0-0 \
    libdrm2 \
    libxkbcommon0 \
    libgbm1 \
    libasound2t64 \
    # OpenGL/EGL 支持 (Tauri 应用需要)
    libegl1 \
    libgl1 \
    libglx0 \
    libopengl0 \
    libgles2 \
    mesa-utils \
    # 中文字体支持
    fonts-wqy-zenhei \
    fonts-wqy-microhei \
    fonts-noto-cjk \
    fonts-noto-cjk-extra \
    # Node.js 环境 (NodeSource) - Node.js 22 LTS
    nodejs \
    # Docker Compose (插件版，支持 docker compose 子命令)
    docker-compose-plugin \
    # locales
    locales && locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8 \
    # 清理缓存
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# 下载 noVNC 源码（Ubuntu 24.04 的 python3-novnc 包不包含 HTML 文件）
RUN mkdir -p /usr/share/novnc && \
    curl -fsSL https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz | tar xzf - -C /usr/share/novnc --strip-components=1 && \
    # 创建 websockify 需要的文件链接
    ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html && \
    # 安装 websockify-js（如果需要）
    if [ -d /usr/share/novnc/utils ]; then \
        mkdir -p /usr/share/novnc/utils/websockify && \
        ln -sf /usr/lib/websockify /usr/share/novnc/utils/websockify/websockify; \
    fi

# 安装 gosu (Ubuntu 24.04 官方仓库无此包，从 GitHub releases 安装)
RUN GOSU_VERSION=1.17 && \
    curl -fsSL https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-$(dpkg --print-architecture) -o /usr/local/bin/gosu && \
    chmod +x /usr/local/bin/gosu && \
    gosu nobody true # 验证安装

# 配置 npm 镜像源（运行时环境变量优先）
RUN if [ -n "$NPM_REGISTRY" ]; then \
        npm config set registry "$NPM_REGISTRY" -g && \
        echo "NPM registry configured: $NPM_REGISTRY"; \
    else \
        npm config set registry "https://registry.npmmirror.com" -g && \
        echo "NPM registry configured: https://registry.npmmirror.com (default)"; \
    fi

# 配置 pip 镜像源（运行时环境变量优先）
RUN if [ -n "$PIP_INDEX_URL" ]; then \
        pip3 config set global.index-url "$PIP_INDEX_URL" && \
        if [ -n "$PIP_TRUSTED_HOST" ]; then \
            pip3 config set global.trusted-host "$PIP_TRUSTED_HOST"; \
        fi && \
        echo "PIP index configured: $PIP_INDEX_URL"; \
    else \
        pip3 config set global.index-url "https://mirrors.aliyun.com/pypi/simple/" && \
        pip3 config set global.trusted-host "mirrors.aliyun.com" && \
        echo "PIP index configured: https://mirrors.aliyun.com/pypi/simple/ (default)"; \
    fi

# 安装 pnpm 和 bun（使用已配置的 npm 镜像源）
RUN npm_config_registry=$(npm config get registry) && \
    npm install -g --prefix /usr/local pnpm bun && \
    pnpm config set registry "$npm_config_registry" -g && \
    echo "pnpm registry configured: $npm_config_registry"

# 安装 uv（快速 Python 包管理器）
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# 创建非 root 用户和 docker 组
# Ubuntu 24.04 预设了 ubuntu 用户 (UID 1000)，删除后创建 agent 用户
RUN if ! getent group docker > /dev/null 2>&1; then \
        groupadd docker; \
    fi && \
    # 删除预设的 ubuntu 用户（如果存在）以释放 UID 1000
    if getent passwd ubuntu > /dev/null 2>&1; then \
        userdel -r ubuntu 2>/dev/null || true; \
    fi && \
    # 创建 agent 用户（UID 1000，与宿主机 data 目录权限匹配）
    useradd -m -s /bin/bash -u 1000 -G docker agent

# 设置工作目录
WORKDIR /home/agent

# 创建必要的目录结构（不创建插件数据目录，避免与符号链接冲突）
RUN mkdir -p tools plugins logs .npm .pip supervisor .cache/uv && \
    touch .bashrc .profile && \
    chown -R agent:agent /home/agent && \
    # 创建 X11 socket 目录（GUI 应用需要）
    mkdir -p /tmp/.X11-unix && \
    chmod 1777 /tmp/.X11-unix

# 复制脚本文件
COPY scripts/ /opt/
RUN chmod +x /opt/*.sh

# 创建 CLI 软链接
RUN ln -s /opt/plugin-manager.sh /usr/local/bin/agentbox

# 容器以 root 启动，entrypoint 中切换到 agent 用户
# 这样可以在启动时配置 Docker socket 等需要 root 权限的操作

# 暴露端口 (文档作用，实际映射由 docker-compose.yml 决定)
# 8080: VS Code Server
# 7681: Web Terminal (ttyd)
# 6080: noVNC (GUI apps like Skills Manager)
EXPOSE 8080 7681 6080

# 设置入口点
ENTRYPOINT ["/opt/entrypoint.sh"]
CMD ["bash"]
