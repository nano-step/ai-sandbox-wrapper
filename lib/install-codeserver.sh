#!/usr/bin/env bash
set -e

# Code-server installer: Browser-based VSCode (fast, no X11 needed)
TOOL="codeserver"
CODESERVER_PORT="${CODESERVER_PORT:-8080}"

echo "Installing $TOOL (code-server - browser-based VSCode)..."

# Create directories
mkdir -p "dockerfiles/$TOOL"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home/.cache"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home"

WORKSPACES_FILE="$HOME/.ai-workspaces"

# Create Dockerfile for code-server
cat <<'EOF' > "dockerfiles/$TOOL/Dockerfile"
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install code-server dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    ca-certificates \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Download and install code-server (latest stable)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then CS_ARCH="amd64"; elif [ "$ARCH" = "arm64" ]; then CS_ARCH="arm64"; else CS_ARCH="amd64"; fi && \
    echo "Downloading code-server for ${CS_ARCH}..." && \
    curl -fsSL https://code-server.dev/install.sh | sh && \
    echo "code-server installed successfully"

# Create directories
RUN mkdir -p /workspace /tmp /home/coder/.config/code-server /home/coder/.local/share/code-server
WORKDIR /workspace

# Non-root user (use UID 1001 to avoid conflicts)
RUN useradd -m -u 1001 -d /home/coder coder && \
    chown -R coder:coder /workspace /tmp /home/coder

USER coder

# Set home directory
ENV HOME=/home/coder

# Expose port
EXPOSE 8080

# Start code-server (no auth for local use, bind to all interfaces)
ENTRYPOINT ["code-server", "--bind-addr", "0.0.0.0:8080", "--auth", "none", "--disable-telemetry"]
CMD ["/workspace"]
EOF

# Build image
echo "Building Docker image for $TOOL..."
docker build ${DOCKER_NO_CACHE:+--no-cache} -t "ai-$TOOL:latest" "dockerfiles/$TOOL"

# Create wrapper script
cat <<'EOF' > "$HOME/bin/codeserver-run"
#!/usr/bin/env bash
# Code-server launcher - opens VSCode in browser

set -e

WORKSPACES_FILE="$HOME/.ai-workspaces"
CONTAINER_NAME="ai-codeserver-sandbox-$$"
CODESERVER_PORT="${CODESERVER_PORT:-8080}"

if [ ! -f "$WORKSPACES_FILE" ]; then
    echo "Error: No workspaces configured. Run setup.sh first." >&2
    exit 1
fi

# Build volume mounts from whitelisted workspaces
VOLUME_MOUNTS=""
WS_INDEX=0
while IFS= read -r ws; do
    if [ -n "$ws" ] && [ -d "$ws" ]; then
        VOLUME_MOUNTS="$VOLUME_MOUNTS -v $ws:/workspace/workspace-$WS_INDEX"
        WS_INDEX=$((WS_INDEX + 1))
    fi
done < "$WORKSPACES_FILE"

if [ $WS_INDEX -eq 0 ]; then
    echo "Error: No valid workspaces found in $WORKSPACES_FILE" >&2
    exit 1
fi

echo "🔒 Starting code-server (browser-based VSCode sandbox)..."
echo ""
echo "Mounted workspaces:"
WS_INDEX=0
while IFS= read -r ws; do
    if [ -n "$ws" ] && [ -d "$ws" ]; then
        echo "  ✓ $ws → /workspace/workspace-$WS_INDEX"
        WS_INDEX=$((WS_INDEX + 1))
    fi
done < "$WORKSPACES_FILE"
echo ""

# Open browser after a short delay
(sleep 2 && open "http://localhost:$CODESERVER_PORT" 2>/dev/null || xdg-open "http://localhost:$CODESERVER_PORT" 2>/dev/null || echo "Open http://localhost:$CODESERVER_PORT in your browser") &

echo "🚀 Starting code-server at http://localhost:$CODESERVER_PORT"
echo "   Press Ctrl+C to stop"
echo ""

# STRICT SANDBOX SECURITY:
# - No host environment variables
# - No access to host files outside volumes
# - Non-root user
# - Only localhost can access the server

docker run \
    --rm \
    --name "$CONTAINER_NAME" \
    $VOLUME_MOUNTS \
    --tmpfs /tmp:exec \
    --tmpfs /run \
    --tmpfs /home/coder/.config:uid=1001,gid=1001 \
    --tmpfs /home/coder/.local:uid=1001,gid=1001 \
    -p 127.0.0.1:$CODESERVER_PORT:8080 \
    -e HOME=/home/coder \
    -e PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    -u 1001:1001 \
    -w /workspace \
    "ai-codeserver:latest"

echo ""
echo "✅ code-server stopped"
echo "🧹 Sandbox cleaned up"
EOF

chmod +x "$HOME/bin/codeserver-run"

echo "✅ $TOOL installed (code-server - browser-based)"
echo ""
echo "Created files:"
echo "  - Docker image: ai-$TOOL:latest"
echo "  - Wrapper script: $HOME/bin/codeserver-run"
echo ""
echo "Features:"
echo "  ✓ Runs in your native browser (fast, crisp)"
echo "  ✓ No X11/XQuartz required"
echo "  ✓ Same sandboxed environment"
echo "  ✓ HiDPI/Retina support"
echo ""
echo "Security Features:"
echo "  ✓ Only accessible from localhost"
echo "  ✓ No host environment variables visible"
echo "  ✓ No access to host filesystem outside volumes"
echo "  ✓ Runs as non-root user"
echo "  ✓ Terminal in VSCode is sandboxed"
echo ""
echo "Usage:"
echo "  codeserver-run"
echo "  # Opens VSCode in browser at http://localhost:$CODESERVER_PORT"
echo ""
echo "Whitelisted Workspaces:"
if [ -f "$WORKSPACES_FILE" ]; then
    while IFS= read -r ws; do
        if [ -n "$ws" ] && [ -d "$ws" ]; then
            echo "  - $ws"
        fi
    done < "$WORKSPACES_FILE"
fi
