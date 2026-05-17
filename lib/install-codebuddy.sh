#!/usr/bin/env bash
set -e

dockerfile_snippet() {
  cat <<'SNIPPET'
USER root
RUN mkdir -p /usr/local/lib/codebuddy && \
    cd /usr/local/lib/codebuddy && \
    bun init -y && \
    bun add @tencent-ai/codebuddy-code && \
    ln -s /usr/local/lib/codebuddy/node_modules/.bin/codebuddy /usr/local/bin/codebuddy
USER agent
SNIPPET
}

if [[ "${SNIPPET_MODE:-}" == "1" ]]; then
  return 0 2>/dev/null || exit 0
fi

TOOL="codebuddy"

echo "Installing $TOOL (Tencent CodeBuddy CLI)..."

# Create directories
mkdir -p "dockerfiles/$TOOL"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home/.cache"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home"

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
