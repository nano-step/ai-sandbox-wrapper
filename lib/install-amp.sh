#!/usr/bin/env bash
set -e

# Amp installer: Sourcegraph's AI coding assistant
TOOL="amp"

echo "Installing $TOOL (Sourcegraph Amp)..."

# Create directories
mkdir -p "dockerfiles/$TOOL"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home/.cache"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home"

# Create Dockerfile (extends base image for faster builds)
cat <<'EOF' > "dockerfiles/$TOOL/Dockerfile"
FROM ai-base:latest

# Switch to root only for installing bun globally (needed for the system)
USER root
RUN npm install -g bun
USER agent

# Install Amp into user directory
RUN mkdir -p /home/agent/lib/amp && \
    cd /home/agent/lib/amp && \
    bun init -y && \
    bun add @sourcegraph/amp

# Add the node_modules .bin to PATH
ENV PATH="/home/agent/lib/amp/node_modules/.bin:${PATH}"

ENTRYPOINT ["amp"]
EOF

# Build image
echo "Building Docker image for $TOOL..."
docker build ${DOCKER_NO_CACHE:+--no-cache} -t "ai-$TOOL:latest" "dockerfiles/$TOOL"

echo "✅ $TOOL installed"
echo ""
echo "Features:"
echo "  ✓ Sourcegraph AI coding assistant"
echo "  ✓ Code understanding and generation"
echo "  ✓ Multi-file editing"
echo ""
echo "Usage: ai-run amp"
