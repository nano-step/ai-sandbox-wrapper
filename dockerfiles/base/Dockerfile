# Build RTK from source (multi-stage: only binary is kept, Rust toolchain discarded)
FROM rust:bookworm AS rtk-builder
RUN cargo install --git https://github.com/rtk-ai/rtk --locked

FROM node:22-bookworm-slim

ARG AGENT_UID=1001

RUN apt-get update && apt-get install -y --no-install-recommends     git     curl     ssh     ca-certificates     jq     python3     python3-pip     python3-venv     python3-dev     python3-setuptools     build-essential     libopenblas-dev     pipx     unzip     xclip     wl-clipboard     ripgrep     tmux     vim-nox     fd-find     sqlite3     poppler-utils     qpdf     tesseract-ocr     && curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin sh     && rm -rf /var/lib/apt/lists/*     && pipx ensurepath

# Install Python PDF processing tools for PDF skill
RUN pip3 install --no-cache-dir --break-system-packages pypdf pdfplumber reportlab pytesseract pdf2image

RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg     && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg     && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null     && apt-get update     && apt-get install -y gh     && rm -rf /var/lib/apt/lists/*

# Install bun (used by most AI tool install scripts)
RUN npm install -g bun

# Install pnpm globally using npm (not bun, for stability)
RUN npm install -g pnpm

# Install TypeScript and LSP tools using npm
RUN npm install -g typescript typescript-language-server pyright vscode-langservers-extracted

# Verify installations
RUN node --version && npm --version && pnpm --version && tsc --version

# Install additional tools (if selected)
RUN PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install specify-cli --pip-args="git+https://github.com/github/spec-kit.git" && \
    chmod +x /usr/local/bin/specify && \
    ln -sf /usr/local/bin/specify /usr/local/bin/specify-cli
RUN mkdir -p /usr/local/lib/uipro-cli && \
    cd /usr/local/lib/uipro-cli && \
    npm init -y && \
    npm install uipro-cli && \
    ln -sf /usr/local/lib/uipro-cli/node_modules/.bin/uipro /usr/local/bin/uipro && \
    ln -sf /usr/local/bin/uipro /usr/local/bin/uipro-cli && \
    chmod -R 755 /usr/local/lib/uipro-cli && \
    chmod +x /usr/local/bin/uipro
RUN mkdir -p /usr/local/lib/openspec && \
    cd /usr/local/lib/openspec && \
    npm init -y && \
    npm install @fission-ai/openspec && \
    ln -sf /usr/local/lib/openspec/node_modules/.bin/openspec /usr/local/bin/openspec && \
    chmod -R 755 /usr/local/lib/openspec && \
    chmod +x /usr/local/bin/openspec
# Install RTK - token optimizer for AI coding agents (built from source)
COPY --from=rtk-builder /usr/local/cargo/bin/rtk /usr/local/bin/rtk
# Install RTK OpenCode skills (auto-discovered by OpenCode agents)
RUN mkdir -p /home/agent/.config/opencode/skills/rtk /home/agent/.config/opencode/skills/rtk-setup
COPY skills/rtk/SKILL.md /home/agent/.config/opencode/skills/rtk/SKILL.md
COPY skills/rtk-setup/SKILL.md /home/agent/.config/opencode/skills/rtk-setup/SKILL.md
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
    libdrm2 \
    libcairo2 \
    libpango-1.0-0 \
    libasound2 \
    fonts-liberation \
    libappindicator3-1 \
    libu2f-udev \
    libvulkan1 \
    libxshmfence1 \
    xdg-utils \
    wget \
    && rm -rf /var/lib/apt/lists/*
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers
RUN mkdir -p /opt/playwright-browsers && \
    npm install -g @playwright/mcp@latest && \
    npx playwright-core install --no-shell chromium && \
    npx playwright-core install-deps chromium && \
    chmod -R 777 /opt/playwright-browsers && \
    ln -sf $(ls -d /opt/playwright-browsers/chromium-*/chrome-linux/chrome | sort -V | tail -1) /opt/chromium
ENV CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS=1
RUN npm install -g chrome-devtools-mcp@latest && \
    touch /opt/.mcp-chrome-devtools-installed

# Create workspace
WORKDIR /workspace

# Non-root user for security (match host UID)
RUN useradd -m -u ${AGENT_UID} -d /home/agent agent && \
    mkdir -p /home/agent/.cache /home/agent/.npm /home/agent/.opencode /home/agent/.config && \
    chown -R agent:agent /home/agent/.cache /home/agent/.npm /home/agent/.opencode /home/agent/.config /workspace && \
    ([ -d /opt/playwright-browsers ] && chown -R agent:agent /opt/playwright-browsers || true)
USER agent
ENV HOME=/home/agent
