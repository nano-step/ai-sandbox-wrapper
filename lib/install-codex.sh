#!/usr/bin/env bash
set -e

dockerfile_snippet() {
  cat <<'SNIPPET'
USER root
RUN mkdir -p /usr/local/lib/codex && \
    cd /usr/local/lib/codex && \
    bun init -y && \
    bun add @openai/codex && \
    ln -s /usr/local/lib/codex/node_modules/.bin/codex /usr/local/bin/codex
USER agent
SNIPPET
}

if [[ "${SNIPPET_MODE:-}" == "1" ]]; then
  return 0 2>/dev/null || exit 0
fi

TOOL="codex"

echo "Installing $TOOL (OpenAI Codex CLI)..."

# Create directories
mkdir -p "dockerfiles/$TOOL"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home/.cache"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home"

# Create Dockerfile (extends base image for faster builds)
cat <<'EOF' > "dockerfiles/$TOOL/Dockerfile"
FROM ai-base:latest
USER root
RUN mkdir -p /usr/local/lib/codex && \
    cd /usr/local/lib/codex && \
    bun init -y && \
    bun add @openai/codex && \
    ln -s /usr/local/lib/codex/node_modules/.bin/codex /usr/local/bin/codex
USER agent
ENTRYPOINT ["codex"]
EOF

# Build image
echo "Building Docker image for $TOOL..."
docker build ${DOCKER_NO_CACHE:+--no-cache} -t "ai-$TOOL:latest" "dockerfiles/$TOOL"

echo "✅ $TOOL installed"
echo ""
echo "Features:"
echo "  ✓ OpenAI's official terminal agent"
echo "  ✓ GPT-4 and Codex models"
echo "  ✓ Multi-file code generation"
echo "  ✓ Terminal command execution"
echo ""
echo "Usage: ai-run codex"
echo "Auth: Set OPENAI_API_KEY environment variable"
