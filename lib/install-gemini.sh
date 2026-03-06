#!/usr/bin/env bash
set -e

dockerfile_snippet() {
  cat <<'SNIPPET'
USER root
RUN mkdir -p /usr/local/lib/gemini && \
    cd /usr/local/lib/gemini && \
    bun init -y && \
    bun add @google/gemini-cli && \
    ln -s /usr/local/lib/gemini/node_modules/.bin/gemini /usr/local/bin/gemini
USER agent
SNIPPET
}

if [[ "${SNIPPET_MODE:-}" == "1" ]]; then
  return 0 2>/dev/null || exit 0
fi

TOOL="gemini"

echo "Installing $TOOL (Google Gemini CLI)..."

# Create directories
mkdir -p "dockerfiles/$TOOL"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home/.cache"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home"

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
