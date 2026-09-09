#!/usr/bin/env bash
set -e

dockerfile_snippet() {
  cat <<'SNIPPET'
USER root
RUN UV_TOOL_BIN_DIR=/usr/local/bin uv tool install aider-chat
USER agent
SNIPPET
}

if [[ "${SNIPPET_MODE:-}" == "1" ]]; then
  return 0 2>/dev/null || exit 0
fi

TOOL="aider"

echo "Installing $TOOL (Python-based AI pair programmer)..."

# Create directories
mkdir -p "dockerfiles/$TOOL"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home/.cache"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home"

# Create Dockerfile (extends base image which has Python)
cat <<'EOF' > "dockerfiles/$TOOL/Dockerfile"
FROM ai-base:${BASE_IMAGE_PRESET:-base}
USER root
RUN UV_TOOL_BIN_DIR=/usr/local/bin uv tool install aider-chat
USER agent
ENTRYPOINT ["aider"]
EOF

# Build image
echo "Building Docker image for $TOOL..."
# Ensure ai-base:<preset> is available (pulled from ghcr.io/nano-step/ai-base, or built locally).
bash "$(dirname "$0")/ensure-ai-base.sh" "${BASE_IMAGE_PRESET:-base}"
docker build ${DOCKER_NO_CACHE:+--no-cache} --network=host -t "ai-$TOOL:latest" "dockerfiles/$TOOL"

echo "✅ $TOOL installed"
echo ""
echo "Usage: ai-run aider [options]"
echo "Example: ai-run aider --model gpt-4"
