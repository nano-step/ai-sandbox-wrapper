#!/usr/bin/env bash
set -e

# Generic tool installer: ./install-tool.sh <tool> <npm-package> <entrypoint>
# Uses Bun runtime for 2x faster startup
TOOL="$1"
NPM_PACKAGE="$2"
ENTRYPOINT="${3:-$TOOL}"

if [[ -z "$TOOL" || -z "$NPM_PACKAGE" ]]; then
  echo "Usage: $0 <tool> <npm-package> [entrypoint]"
  exit 1
fi

echo "Installing $TOOL..."

# Create directories
mkdir -p "dockerfiles/$TOOL"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home/.cache"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home"

# Create Dockerfile using Bun
cat <<EOF > "dockerfiles/$TOOL/Dockerfile"
FROM ai-base:${BASE_IMAGE_PRESET:-base}
USER root
RUN mkdir -p /usr/local/lib/$TOOL && \
    cd /usr/local/lib/$TOOL && \
    bun init -y && \
    bun add $NPM_PACKAGE && \
    ln -s /usr/local/lib/$TOOL/node_modules/.bin/$ENTRYPOINT /usr/local/bin/$ENTRYPOINT
USER agent
ENTRYPOINT ["$ENTRYPOINT"]
EOF

# Build image
echo "Building Docker image for $TOOL..."
# Ensure ai-base:<preset> is available (pulled from ghcr.io/nano-step/ai-base, or built locally).
bash "$(dirname "$0")/ensure-ai-base.sh" "${BASE_IMAGE_PRESET:-base}"
docker build ${DOCKER_NO_CACHE:+--no-cache} --network=host -t "ai-$TOOL:latest" "dockerfiles/$TOOL"

echo "✅ $TOOL installed"

