FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

# 安装基础依赖（先安装 Node.js）
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    git \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# 配置 npm 镜像源并预安装 gitnexus
RUN npm config set registry https://registry.npmmirror.com -g \
    && npm install -g gitnexus \
    && npm cache clean --force

# 应用补丁：覆盖 api.js 以修复 CORS 或其他问题
COPY patch/api.js /usr/lib/node_modules/gitnexus/dist/server/api.js

WORKDIR /app