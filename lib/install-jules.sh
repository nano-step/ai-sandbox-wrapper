#!/usr/bin/env bash
set -e

dockerfile_snippet() {
  cat <<'SNIPPET'
USER root
RUN mkdir -p /usr/local/lib/jules && \
    cd /usr/local/lib/jules && \
    bun init -y && \
    bun add @google/jules && \
    ln -s /usr/local/lib/jules/node_modules/.bin/jules /usr/local/bin/jules
USER agent
SNIPPET
}

if [[ "${SNIPPET_MODE:-}" == "1" ]]; then
  return 0 2>/dev/null || exit 0
fi

TOOL="jules"

echo "Installing $TOOL (Google Jules CLI)..."

# Create directories
mkdir -p "dockerfiles/$TOOL"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home/.cache"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home"

# Create Dockerfile
cat <<'EOF' > "dockerfiles/$TOOL/Dockerfile"
FROM ai-base:latest
USER root

# Install Jules CLI to a non-shadowed path
RUN mkdir -p /usr/local/lib/jules && \
    cd /usr/local/lib/jules && \
    bun init -y && \
    bun add @google/jules && \
    ln -s /usr/local/lib/jules/node_modules/.bin/jules /usr/local/bin/jules

USER agent
ENTRYPOINT ["jules"]
EOF

# Build image
echo "Building Docker image for $TOOL..."
docker build ${DOCKER_NO_CACHE:+--no-cache} -t "ai-$TOOL:latest" "dockerfiles/$TOOL"

echo "✅ $TOOL installed"
echo ""
echo "Usage: ai-run jules"
