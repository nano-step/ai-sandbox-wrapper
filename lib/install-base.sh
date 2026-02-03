#!/usr/bin/env bash
set -e

# Build base Docker image with Bun runtime (2x faster than Node.js)
mkdir -p "dockerfiles/base"

ADDITIONAL_TOOLS_INSTALL=""

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

cat > "dockerfiles/base/Dockerfile" <<EOF
FROM node:22-bookworm-slim

ARG AGENT_UID=1001

# Install common dependencies
# Note: python3-venv is needed for many tools, unzip for some installers
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
    && curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin sh \
    && rm -rf /var/lib/apt/lists/* \
    && pipx ensurepath

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

# Non-root user for security
# Non-root user for security (match host UID)
RUN useradd -m -u \${AGENT_UID} -d /home/agent agent && \\
    mkdir -p /home/agent/.cache /home/agent/.npm /home/agent/.opencode /home/agent/.config && \\
    chown -R agent:agent /home/agent/.cache /home/agent/.npm /home/agent/.opencode /home/agent/.config /workspace
USER agent
ENV HOME=/home/agent
EOF

echo "Building base Docker image..."
HOST_UID=$(id -u)
docker build ${DOCKER_NO_CACHE:+--no-cache} \
  --build-arg AGENT_UID="${HOST_UID}" \
  -t "ai-base:latest" "dockerfiles/base"
echo "✅ Base image built (ai-base:latest)"

