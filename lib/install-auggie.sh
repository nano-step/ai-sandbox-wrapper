#!/usr/bin/env bash
set -e

dockerfile_snippet() {
  cat <<'SNIPPET'
USER root
RUN mkdir -p /usr/local/lib/auggie && \
    cd /usr/local/lib/auggie && \
    bun init -y && \
    bun add @augmentcode/auggie && \
    ln -s /usr/local/lib/auggie/node_modules/.bin/auggie /usr/local/bin/auggie
USER agent
SNIPPET
}

if [[ "${SNIPPET_MODE:-}" == "1" ]]; then
  return 0 2>/dev/null || exit 0
fi

TOOL="auggie"

echo "Installing $TOOL (Augment Auggie CLI)..."

# Create directories
mkdir -p "dockerfiles/$TOOL"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home/.cache"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home"

# Create Dockerfile
cat <<'EOF' > "dockerfiles/$TOOL/Dockerfile"
FROM ai-base:${BASE_IMAGE_PRESET:-base}
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
# Ensure ai-base:<preset> is available (pulled from ghcr.io/nano-step/ai-base, or built locally).
bash "$(dirname "$0")/ensure-ai-base.sh" "${BASE_IMAGE_PRESET:-base}"
docker build ${DOCKER_NO_CACHE:+--no-cache} --network=host -t "ai-$TOOL:latest" "dockerfiles/$TOOL"

echo "✅ $TOOL installed"
echo ""
echo "Usage: ai-run auggie"
