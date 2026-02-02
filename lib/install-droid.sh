#!/usr/bin/env bash
set -e

echo "Installing droid (Factory CLI)..."

# Create directories
mkdir -p "dockerfiles/droid"
mkdir -p "$HOME/.ai-sandbox/tools/droid/home/.cache"
mkdir -p "$HOME/.ai-sandbox/tools/droid/home"

# Create Dockerfile with curl install
cat <<'EOF' > "dockerfiles/droid/Dockerfile"
FROM ai-base:latest
USER root
RUN mkdir -p /home/agent/.factory && \
    bash -c "curl -fsSL https://app.factory.ai/cli | sh" && \
    mv /home/agent/.local/bin/droid /usr/local/bin/droid && \
    chown -R agent:agent /home/agent/.factory
USER agent
ENTRYPOINT ["bash", "-c", "exec droid \"$@\"", "--"]
EOF

# Build image
echo "Building Docker image for droid..."
docker build ${DOCKER_NO_CACHE:+--no-cache} -t "ai-droid:latest" "dockerfiles/droid"

echo "✅ droid installed"
