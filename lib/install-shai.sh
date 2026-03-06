#!/usr/bin/env bash
set -e

dockerfile_snippet() {
  cat <<'SNIPPET'
USER root
RUN curl -fsSL https://raw.githubusercontent.com/ovh/shai/main/install.sh | bash && \
    mv /home/agent/.local/bin/shai /usr/local/bin/shai
USER agent
SNIPPET
}

if [[ "${SNIPPET_MODE:-}" == "1" ]]; then
  return 0 2>/dev/null || exit 0
fi

TOOL="shai"

echo "Installing $TOOL (OVHcloud SHAI)..."

# Create directories
mkdir -p "dockerfiles/$TOOL"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home/.cache"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home"

# Create Dockerfile
cat <<'EOF' > "dockerfiles/$TOOL/Dockerfile"
FROM ai-base:latest
USER root

# Install SHAI native binary and relocate to /usr/local/bin
RUN curl -fsSL https://raw.githubusercontent.com/ovh/shai/main/install.sh | bash && \
    mv /home/agent/.local/bin/shai /usr/local/bin/shai

USER agent
ENTRYPOINT ["shai"]
EOF

# Build image
echo "Building Docker image for $TOOL..."
docker build ${DOCKER_NO_CACHE:+--no-cache} -t "ai-$TOOL:latest" "dockerfiles/$TOOL"

echo "✅ $TOOL installed"
echo ""
echo "Usage: ai-run shai"
