#!/usr/bin/env bash
set -e

# Kilo Code installer: Multi-model AI coding agent
# Note: Uses npm instead of bun due to cheerio dependency resolution issue
TOOL="kilo"

echo "Installing $TOOL (Kilo Code CLI)..."

# Create directories
mkdir -p "dockerfiles/$TOOL"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home/.cache"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home"

# Create Dockerfile - use Node.js for this tool due to Bun compatibility issue
cat <<'EOF' > "dockerfiles/$TOOL/Dockerfile"
FROM node:22-slim

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ssh \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Kilo Code CLI as root
RUN npm install -g @kilocode/cli

# Create workspace
WORKDIR /workspace

# Create worker user
RUN useradd -m -u 1001 -d /home/agent agent && \
    chown -R agent:agent /workspace

USER agent
ENV HOME=/home/agent

# Kilo uses 'kilocode' as entrypoint
ENTRYPOINT ["kilocode"]
EOF

# Build image
echo "Building Docker image for $TOOL..."
docker build ${DOCKER_NO_CACHE:+--no-cache} -t "ai-$TOOL:latest" "dockerfiles/$TOOL"

echo "✅ $TOOL installed"
echo ""
echo "Features:"
echo "  ✓ 500+ AI models supported"
echo "  ✓ Parallel agents with git worktrees"
echo "  ✓ Orchestrator mode for complex tasks"
echo "  ✓ Multiple modes: ask, architect, code, debug"
echo ""
echo "Usage: ai-run kilo"
echo "Modes: ai-run kilo --mode architect"
