#!/usr/bin/env bash
set -e

# CodeBuddy CLI installer: Tencent's AI assistant
TOOL="codebuddy"

echo "Installing $TOOL (Tencent CodeBuddy CLI)..."

# Create directories
mkdir -p "dockerfiles/$TOOL"
mkdir -p "$HOME/.ai-sandbox/cache/$TOOL"
mkdir -p "$HOME/.ai-sandbox/home/$TOOL"

# Create Dockerfile
cat <<'EOF' > "dockerfiles/$TOOL/Dockerfile"
FROM ai-base:latest
USER root

# Install CodeBuddy CLI to a non-shadowed path
RUN mkdir -p /usr/local/lib/codebuddy && \
    cd /usr/local/lib/codebuddy && \
    bun init -y && \
    bun add @tencent-ai/codebuddy-code && \
    ln -s /usr/local/lib/codebuddy/node_modules/.bin/codebuddy /usr/local/bin/codebuddy

USER agent
ENTRYPOINT ["codebuddy"]
EOF

# Build image
echo "Building Docker image for $TOOL..."
docker build ${DOCKER_NO_CACHE:+--no-cache} -t "ai-$TOOL:latest" "dockerfiles/$TOOL"

echo "✅ $TOOL installed"
echo ""
echo "Usage: ai-run codebuddy"
