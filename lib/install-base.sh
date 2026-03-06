#!/usr/bin/env bash
set -e

# Build base Docker image with Bun runtime (2x faster than Node.js)
mkdir -p "dockerfiles/base"

ADDITIONAL_TOOLS_INSTALL=""
DOCKERFILE_BUILD_STAGES=""

if [[ "${INSTALL_SPEC_KIT:-0}" -eq 1 ]]; then
  echo "📦 spec-kit will be installed in base image"
  ADDITIONAL_TOOLS_INSTALL+='RUN PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install specify-cli --pip-args="git+https://github.com/github/spec-kit.git" && \
    chmod +x /usr/local/bin/specify && \
    ln -sf /usr/local/bin/specify /usr/local/bin/specify-cli
'
fi

if [[ "${INSTALL_UX_UI_PROMAX:-0}" -eq 1 ]]; then
  echo "📦 ux-ui-promax will be installed in base image"
  ADDITIONAL_TOOLS_INSTALL+='RUN mkdir -p /usr/local/lib/uipro-cli && \
    cd /usr/local/lib/uipro-cli && \
    npm init -y && \
    npm install uipro-cli && \
    ln -sf /usr/local/lib/uipro-cli/node_modules/.bin/uipro /usr/local/bin/uipro && \
    ln -sf /usr/local/bin/uipro /usr/local/bin/uipro-cli && \
    chmod -R 755 /usr/local/lib/uipro-cli && \
    chmod +x /usr/local/bin/uipro
'
fi

if [[ "${INSTALL_OPENSPEC:-0}" -eq 1 ]]; then
  echo "📦 OpenSpec will be installed in base image"
  ADDITIONAL_TOOLS_INSTALL+='RUN mkdir -p /usr/local/lib/openspec && \
    cd /usr/local/lib/openspec && \
    npm init -y && \
    npm install @fission-ai/openspec && \
    ln -sf /usr/local/lib/openspec/node_modules/.bin/openspec /usr/local/bin/openspec && \
    chmod -R 755 /usr/local/lib/openspec && \
    chmod +x /usr/local/bin/openspec
'
fi

if [[ "${INSTALL_RTK:-0}" -eq 1 ]]; then
  echo "📦 RTK (Rust Token Killer) will be installed in base image (multi-stage build)"
  DOCKERFILE_BUILD_STAGES+='# Build RTK from source (multi-stage: only binary is kept, Rust toolchain discarded)
FROM rust:bookworm AS rtk-builder
RUN cargo install --git https://github.com/rtk-ai/rtk --locked
'
  ADDITIONAL_TOOLS_INSTALL+='# Install RTK - token optimizer for AI coding agents (built from source)
COPY --from=rtk-builder /usr/local/cargo/bin/rtk /usr/local/bin/rtk
'
  # Copy RTK OpenCode skills into build context so they can be COPY'd into the image
  SCRIPT_BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  RTK_SKILLS_SRC="${SCRIPT_BASE_DIR}/../skills"
  if [[ -d "$RTK_SKILLS_SRC/rtk" && -d "$RTK_SKILLS_SRC/rtk-setup" ]]; then
    mkdir -p "dockerfiles/base/skills/rtk" "dockerfiles/base/skills/rtk-setup"
    cp "$RTK_SKILLS_SRC/rtk/SKILL.md" "dockerfiles/base/skills/rtk/SKILL.md"
    cp "$RTK_SKILLS_SRC/rtk-setup/SKILL.md" "dockerfiles/base/skills/rtk-setup/SKILL.md"
    ADDITIONAL_TOOLS_INSTALL+='# Install RTK OpenCode skills (auto-discovered by OpenCode agents)
RUN mkdir -p /home/agent/.config/opencode/skills/rtk /home/agent/.config/opencode/skills/rtk-setup
COPY skills/rtk/SKILL.md /home/agent/.config/opencode/skills/rtk/SKILL.md
COPY skills/rtk-setup/SKILL.md /home/agent/.config/opencode/skills/rtk-setup/SKILL.md
'
    echo "  ✅ RTK OpenCode skills will be copied into container"
  else
    echo "  ⚠️  RTK skills not found at $RTK_SKILLS_SRC — skipping skill installation"
  fi
fi

if [[ "${INSTALL_PLAYWRIGHT:-0}" -eq 1 ]]; then
  echo "📦 Playwright will be installed in base image"
  ADDITIONAL_TOOLS_INSTALL+='# Install Playwright system dependencies
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
# Install Playwright and browsers via npm
RUN npm install -g playwright && npx playwright install
'
fi

if [[ "${INSTALL_RUBY:-0}" -eq 1 ]]; then
  echo "📦 Ruby 3.3.0 + Rails 8.0.2 will be installed in base image"
  ADDITIONAL_TOOLS_INSTALL+='RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    libyaml-dev \
    libffi-dev \
    libgdbm-dev \
    libncurses5-dev \
    libpq-dev \
    default-libmysqlclient-dev \
    libsqlite3-dev \
    imagemagick \
    libmagickwand-dev \
    libvips-dev \
    autoconf \
    bison \
    rustc \
    libxml2-dev \
    libxslt1-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/rbenv/rbenv.git /usr/local/rbenv && \
    git clone https://github.com/rbenv/ruby-build.git /usr/local/rbenv/plugins/ruby-build

ENV RBENV_ROOT=/usr/local/rbenv
ENV PATH=$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH

RUN rbenv install 3.3.0 && rbenv global 3.3.0 && rbenv rehash

RUN gem install rails -v 8.0.2 && gem install bundler && rbenv rehash
'
fi

# MCP Tools for AI agent browser automation
# Both tools share Playwright's Chromium (native ARM64/x86_64, avoids Puppeteer arch issues)
MCP_BROWSER_INSTALLED=false

if [[ "${INSTALL_CHROME_DEVTOOLS_MCP:-0}" -eq 1 ]] || [[ "${INSTALL_PLAYWRIGHT_MCP:-0}" -eq 1 ]]; then
  MCP_BROWSER_INSTALLED=true
  echo "📦 Installing shared Chromium browser for MCP tools"
  ADDITIONAL_TOOLS_INSTALL+='RUN apt-get update && apt-get install -y --no-install-recommends \
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
    ln -sf $(ls -d /opt/playwright-browsers/chromium-*/chrome-linux/chrome | head -1) /opt/chromium
'
fi

if [[ "${INSTALL_CHROME_DEVTOOLS_MCP:-0}" -eq 1 ]]; then
  echo "📦 Chrome DevTools MCP will be installed in base image"
  ADDITIONAL_TOOLS_INSTALL+='ENV CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS=1
RUN npm install -g chrome-devtools-mcp@latest && \
    touch /opt/.mcp-chrome-devtools-installed
'
fi

if [[ "${INSTALL_PLAYWRIGHT_MCP:-0}" -eq 1 ]]; then
  echo "📦 Playwright MCP will be installed in base image"
  ADDITIONAL_TOOLS_INSTALL+='RUN touch /opt/.mcp-playwright-installed
'
fi

cat > "dockerfiles/base/Dockerfile" <<EOF
${DOCKERFILE_BUILD_STAGES}
FROM node:22-bookworm-slim

ARG AGENT_UID=1001

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
    unzip \
    xclip \
    wl-clipboard \
    ripgrep \
    && curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin sh \
    && rm -rf /var/lib/apt/lists/* \
    && pipx ensurepath

RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Install bun (used by most AI tool install scripts)
RUN npm install -g bun

# Install pnpm globally using npm (not bun, for stability)
RUN npm install -g pnpm

# Install TypeScript and LSP tools using npm
RUN npm install -g typescript typescript-language-server

# Verify installations
RUN node --version && npm --version && pnpm --version && tsc --version

# Install additional tools (if selected)
${ADDITIONAL_TOOLS_INSTALL}
# Create workspace
WORKDIR /workspace

# Non-root user for security (match host UID)
RUN useradd -m -u \${AGENT_UID} -d /home/agent agent && \\
    mkdir -p /home/agent/.cache /home/agent/.npm /home/agent/.opencode /home/agent/.config && \\
    chown -R agent:agent /home/agent/.cache /home/agent/.npm /home/agent/.opencode /home/agent/.config /workspace && \\
    ([ -d /opt/playwright-browsers ] && chown -R agent:agent /opt/playwright-browsers || true)
USER agent
ENV HOME=/home/agent
EOF

# GENERATE_ONLY mode: write Dockerfile but don't build
if [[ "${GENERATE_ONLY:-0}" -eq 1 ]]; then
  echo "✅ Base Dockerfile generated at dockerfiles/base/Dockerfile"
  exit 0
fi

echo "Building base Docker image..."
HOST_UID=$(id -u)
docker build ${DOCKER_NO_CACHE:+--no-cache} \
  --build-arg AGENT_UID="${HOST_UID}" \
  -t "ai-base:latest" "dockerfiles/base"
echo "✅ Base image built (ai-base:latest)"
