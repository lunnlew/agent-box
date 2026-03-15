# AgentBox Dockerfile
# 基于Ubuntu 22.04的可插拔AI Agent工具集成容器

FROM ubuntu:22.04

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

# 配置 Ubuntu APT 镜像源
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
        sed -i "s@archive.ubuntu.com@${MIRROR_URL}@g" /etc/apt/sources.list && \
        sed -i "s@security.ubuntu.com@${MIRROR_URL}@g" /etc/apt/sources.list; \
    fi

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    # 基础工具
    curl \
    wget \
    git \
    gnupg \
    ca-certificates \
    gosu \
    # Python环境
    python3 \
    python3-pip \
    python3-venv \
    # Supervisor 进程管理
    supervisor \
    # GUI 支持 (noVNC)
    xvfb \
    x11vnc \
    novnc \
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
    libasound2 \
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
    # Node.js环境 (NodeSource) - Node.js 22 LTS
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    # 清理缓存
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

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

# 创建非root用户和docker组
RUN groupadd -g 999 docker && \
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

# 创建CLI软链接
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