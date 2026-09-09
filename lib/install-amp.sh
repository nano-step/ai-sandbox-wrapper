#!/usr/bin/env bash
set -e

dockerfile_snippet() {
  cat <<'SNIPPET'
USER root
RUN mkdir -p /usr/local/lib/amp && \
    cd /usr/local/lib/amp && \
    bun init -y && \
    bun add @sourcegraph/amp && \
    ln -s /usr/local/lib/amp/node_modules/.bin/amp /usr/local/bin/amp
SNIPPET
}

if [[ "${SNIPPET_MODE:-}" == "1" ]]; then
  return 0 2>/dev/null || exit 0
fi

TOOL="amp"

echo "Installing $TOOL (Sourcegraph Amp)..."

# Create directories
mkdir -p "dockerfiles/$TOOL"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home/.cache"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home"

# Create Dockerfile (extends base image for faster builds)
cat <<'EOF' > "dockerfiles/$TOOL/Dockerfile"
FROM ai-base:${BASE_IMAGE_PRESET:-base}

USER root
RUN mkdir -p /usr/local/lib/amp && \
    cd /usr/local/lib/amp && \
    bun init -y && \
    bun add @sourcegraph/amp && \
    ln -s /usr/local/lib/amp/node_modules/.bin/amp /usr/local/bin/amp

USER agent
ENTRYPOINT ["amp"]
EOF

# Build image
echo "Building Docker image for $TOOL..."
# Ensure ai-base:<preset> is available (pulled from ghcr.io/nano-step/ai-base, or built locally).
bash "$(dirname "$0")/ensure-ai-base.sh" "${BASE_IMAGE_PRESET:-base}"
docker build ${DOCKER_NO_CACHE:+--no-cache} --network=host -t "ai-$TOOL:latest" "dockerfiles/$TOOL"

echo "✅ $TOOL installed"
echo ""
echo "Features:"
echo "  ✓ Sourcegraph AI coding assistant"
echo "  ✓ Code understanding and generation"
echo "  ✓ Multi-file editing"
echo ""
echo "Usage: ai-run amp"
