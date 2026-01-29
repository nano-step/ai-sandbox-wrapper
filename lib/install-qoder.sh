#!/usr/bin/env bash
set -e

# Qoder CLI installer: Qoder's AI coding assistant
TOOL="qoder"

echo "Installing $TOOL (Qoder AI CLI)..."

# Create directories
mkdir -p "dockerfiles/$TOOL"
mkdir -p "$HOME/.ai-sandbox/cache/$TOOL"
mkdir -p "$HOME/.ai-sandbox/home/$TOOL"

# Create Dockerfile
cat <<'EOF' > "dockerfiles/$TOOL/Dockerfile"
FROM ai-base:latest
USER root

# Install Qoder CLI to a non-shadowed path
RUN mkdir -p /usr/local/lib/qoder && \
    cd /usr/local/lib/qoder && \
    bun init -y && \
    bun add @qoder-ai/qodercli && \
    ln -s /usr/local/lib/qoder/node_modules/.bin/qodercli /usr/local/bin/qoder

USER agent
ENTRYPOINT ["qoder"]
EOF

# Build image
echo "Building Docker image for $TOOL..."
docker build ${DOCKER_NO_CACHE:+--no-cache} -t "ai-$TOOL:latest" "dockerfiles/$TOOL"

echo "✅ $TOOL installed"
echo ""
echo "Usage: ai-run qoder"
echo "Auth: Set QODER_API_KEY environment variable"
