#!/usr/bin/env bash
set -e

# Gemini CLI installer: Google's AI coding agent
TOOL="gemini"

echo "Installing $TOOL (Google Gemini CLI)..."

# Create directories
mkdir -p "dockerfiles/$TOOL"
mkdir -p "$HOME/.ai-sandbox/cache/$TOOL"
mkdir -p "$HOME/.ai-sandbox/home/$TOOL"

# Create Dockerfile (extends base image for faster builds)
cat <<'EOF' > "dockerfiles/$TOOL/Dockerfile"
FROM ai-base:latest
USER root
RUN mkdir -p /usr/local/lib/gemini && \
    cd /usr/local/lib/gemini && \
    bun init -y && \
    bun add @google/gemini-cli && \
    ln -s /usr/local/lib/gemini/node_modules/.bin/gemini /usr/local/bin/gemini
USER agent
ENTRYPOINT ["gemini"]
EOF

# Build image
echo "Building Docker image for $TOOL..."
docker build ${DOCKER_NO_CACHE:+--no-cache} -t "ai-$TOOL:latest" "dockerfiles/$TOOL"

echo "✅ $TOOL installed"
echo ""
echo "Features:"
echo "  ✓ Free tier with Gemini 2.5 Pro"
echo "  ✓ MCP (Model Context Protocol) support"
echo "  ✓ Google Search grounding"
echo ""
echo "Usage: ai-run gemini"
echo "Auth: Set GOOGLE_API_KEY or use 'gemini auth'"
