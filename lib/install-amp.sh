#!/usr/bin/env bash
set -e

# Amp installer: Sourcegraph's AI coding assistant
TOOL="amp"

echo "Installing $TOOL (Sourcegraph Amp)..."

# Create directories
mkdir -p "dockerfiles/$TOOL"
mkdir -p "$HOME/.ai-sandbox/cache/$TOOL"
mkdir -p "$HOME/.ai-sandbox/home/$TOOL"

# Create Dockerfile (extends base image for faster builds)
cat <<'EOF' > "dockerfiles/$TOOL/Dockerfile"
FROM ai-base:latest
USER root
# Install Amp globally into a persistent directory (not shadowed by home)
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
docker build ${DOCKER_NO_CACHE:+--no-cache} -t "ai-$TOOL:latest" "dockerfiles/$TOOL"

echo "✅ $TOOL installed"
echo ""
echo "Features:"
echo "  ✓ Sourcegraph AI coding assistant"
echo "  ✓ Code understanding and generation"
echo "  ✓ Multi-file editing"
echo ""
echo "Usage: ai-run amp"
