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
RUN PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install specify-cli --pip-args="git+https://github.com/github/spec-kit.git" && \
    chmod +x /usr/local/bin/specify && \
    ln -sf /usr/local/bin/specify /usr/local/bin/specify-cli
RUN mkdir -p /usr/local/lib/uipro-cli && \
    cd /usr/local/lib/uipro-cli && \
    bun init -y && \
    bun add uipro-cli && \
    ln -sf /usr/local/lib/uipro-cli/node_modules/.bin/uipro /usr/local/bin/uipro && \
    ln -sf /usr/local/bin/uipro /usr/local/bin/uipro-cli && \
    chmod -R 755 /usr/local/lib/uipro-cli && \
    chmod +x /usr/local/bin/uipro

# Create workspace
WORKDIR /workspace

# Non-root user for security
RUN useradd -m -u 1001 -d /home/agent agent && \
    chown -R agent:agent /workspace
USER agent
ENV HOME=/home/agent
