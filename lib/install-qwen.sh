#!/usr/bin/env bash
set -e

# Qwen Code installer: Alibaba's AI coding agent
TOOL="qwen"

echo "Installing $TOOL (Alibaba Qwen Code CLI)..."

# Create directories
mkdir -p "dockerfiles/$TOOL"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home/.cache"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home"

# Create Dockerfile (extends base image for faster builds)
cat <<'EOF' > "dockerfiles/$TOOL/Dockerfile"
FROM ai-base:latest
USER root
# Install qwen-code in a dedicated directory and symlink to /usr/local/bin
RUN mkdir -p /usr/local/lib/qwen && \
    cd /usr/local/lib/qwen && \
    bun init -y && \
    bun add @qwen-code/qwen-code@latest tiktoken && \
    ln -s /usr/local/lib/qwen/node_modules/.bin/qwen /usr/local/bin/qwen
USER agent
ENTRYPOINT ["qwen"]
EOF

# Build image
echo "Building Docker image for $TOOL..."
docker build ${DOCKER_NO_CACHE:+--no-cache} -t "ai-$TOOL:latest" "dockerfiles/$TOOL"

echo "✅ $TOOL installed"
echo ""
echo "Features:"
echo "  ✓ Qwen3-Coder model (1M context)"
echo "  ✓ Agentic programming workflows"
echo "  ✓ Multi-file code editing"
echo ""
echo "Usage: ai-run qwen"
echo "Auth: Set DASHSCOPE_API_KEY or configure endpoint"
