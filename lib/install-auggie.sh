#!/usr/bin/env bash
set -e

# Auggie CLI installer: Augment Code's AI assistant
TOOL="auggie"

echo "Installing $TOOL (Augment Auggie CLI)..."

# Create directories
mkdir -p "dockerfiles/$TOOL"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home/.cache"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home"

# Create Dockerfile
cat <<'EOF' > "dockerfiles/$TOOL/Dockerfile"
FROM ai-base:latest
USER root

# Install Auggie CLI to a non-shadowed path
RUN mkdir -p /usr/local/lib/auggie && \
    cd /usr/local/lib/auggie && \
    bun init -y && \
    bun add @augmentcode/auggie && \
    ln -s /usr/local/lib/auggie/node_modules/.bin/auggie /usr/local/bin/auggie

USER agent
ENTRYPOINT ["auggie"]
EOF

# Build image
echo "Building Docker image for $TOOL..."
docker build ${DOCKER_NO_CACHE:+--no-cache} -t "ai-$TOOL:latest" "dockerfiles/$TOOL"

echo "✅ $TOOL installed"
echo ""
echo "Usage: ai-run auggie"
