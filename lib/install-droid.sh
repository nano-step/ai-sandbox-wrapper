#!/usr/bin/env bash
set -e

dockerfile_snippet() {
  cat <<'SNIPPET'
USER root
RUN mkdir -p /home/agent/.factory && chown -R agent:agent /home/agent/.factory && \
    export HOME=/root && bash -c "curl -fsSL https://app.factory.ai/cli | sh" && \
    mv /root/.local/bin/droid /usr/local/bin/droid
USER agent
SNIPPET
}

if [[ "${SNIPPET_MODE:-}" == "1" ]]; then
  return 0 2>/dev/null || exit 0
fi

echo "Installing droid (Factory CLI)..."

# Create directories
mkdir -p "dockerfiles/droid"
mkdir -p "$HOME/.ai-sandbox/tools/droid/home/.cache"
mkdir -p "$HOME/.ai-sandbox/tools/droid/home"

# Create Dockerfile with curl install
cat <<'EOF' > "dockerfiles/droid/Dockerfile"
FROM ai-base:latest
USER root
RUN mkdir -p /home/agent/.factory && chown -R agent:agent /home/agent/.factory && \
    export HOME=/root && bash -c "curl -fsSL https://app.factory.ai/cli | sh" && \
    mv /root/.local/bin/droid /usr/local/bin/droid
USER agent
ENTRYPOINT ["bash", "-c", "exec droid \"$@\"", "--"]
EOF

# Build image
echo "Building Docker image for droid..."
docker build ${DOCKER_NO_CACHE:+--no-cache} -t "ai-droid:latest" "dockerfiles/droid"

echo "✅ droid installed"
