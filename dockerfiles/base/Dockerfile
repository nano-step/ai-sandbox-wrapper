FROM oven/bun:latest

# Install common dependencies (Bun + Node.js + Python for full package manager support)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ssh \
    ca-certificates \
    jq \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    python3-setuptools \
    build-essential \
    libopenblas-dev \
    pipx \
    && curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin sh \
    && rm -rf /var/lib/apt/lists/* \
    && pipx ensurepath

# Install Node.js LTS (includes npm) via NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install pnpm globally via npm
RUN npm install -g pnpm

# Install TypeScript and LSP tools for AI coding assistants
RUN npm install -g typescript typescript-language-server

# Verify installations
RUN node --version && npm --version && pnpm --version && bun --version && tsc --version

# Install additional tools (if selected)
RUN pipx install specify-cli --pip-args="git+https://github.com/github/spec-kit.git"
RUN bun install -g uipro-cli
RUN mkdir -p /usr/local/lib/openspec && \
    cd /usr/local/lib/openspec && \
    bun init -y && \
    bun add @fission-ai/openspec && \
    ln -sf /usr/local/lib/openspec/node_modules/.bin/openspec /usr/local/bin/openspec
# Install Playwright system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 \
    libnspr4 \
    libnss3 \
    libdbus-1-3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libxcb1 \
    libxkbcommon0 \
    libatspi2.0-0 \
    libx11-6 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libcairo2 \
    libpango-1.0-0 \
    libasound2 \
    && rm -rf /var/lib/apt/lists/*
# Install Playwright and browsers via npm (avoids pnpm global bin issues)
RUN npm install -g playwright && npx playwright install

# Create workspace
WORKDIR /workspace

# Non-root user for security
RUN useradd -m -u 1001 -d /home/agent agent && \
    chown -R agent:agent /workspace
USER agent
ENV HOME=/home/agent
