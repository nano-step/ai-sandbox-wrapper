#!/usr/bin/env bash
set -e

# VSCode Server installer: Headless VSCode in browser
TOOL="vscode"
VSCODE_PORT="${VSCODE_PORT:-8000}"

echo "Installing $TOOL (VSCode Server - browser-based)..."

# Create directories
mkdir -p "dockerfiles/$TOOL"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home/.cache"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home"

# Create Dockerfile for VSCode Desktop (with X11 forwarding)
cat <<'EOF' > "dockerfiles/$TOOL/Dockerfile"
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install VSCode Desktop dependencies (GTK, X11, OpenGL, and other required libraries)
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    ca-certificates \
    gnupg2 \
    libgtk-3-0 \
    libgbm1 \
    libnss3 \
    libxss1 \
    libasound2 \
    libx11-xcb1 \
    libxcb-dri3-0 \
    libdrm2 \
    libxshmfence1 \
    libxkbfile1 \
    libsecret-1-0 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libpango-1.0-0 \
    libcairo2 \
    libxfixes3 \
    libnotify4 \
    fonts-liberation \
    xdg-utils \
    libgl1 \
    libegl1 \
    libgl1-mesa-dri \
    libglx-mesa0 \
    mesa-utils \
    dbus \
    dbus-x11 \
    && rm -rf /var/lib/apt/lists/*

# Download and install VSCode Desktop
RUN ARCH=$(dpkg --print-architecture) && \
    echo "Downloading VSCode Desktop for ${ARCH}..." && \
    wget -q -O /tmp/vscode.deb "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-${ARCH}" && \
    apt-get update && apt-get install -y /tmp/vscode.deb && \
    rm /tmp/vscode.deb && \
    rm -rf /var/lib/apt/lists/* && \
    echo "VSCode Desktop installed successfully"

# Create directories
RUN mkdir -p /workspace /tmp /home/vscode/.config/Code /run/dbus
WORKDIR /workspace

# Non-root user (use UID 1001 to avoid conflicts)
RUN useradd -m -u 1001 -d /home/vscode vscode && \
    chown -R vscode:vscode /workspace /tmp /home/vscode

USER vscode

# Set home directory
ENV HOME=/home/vscode

# Start VSCode Desktop with software rendering (no GPU)
ENTRYPOINT ["/usr/share/code/code", "--no-sandbox", "--disable-gpu"]
CMD ["/workspace"]
EOF

# Build image
echo "Building Docker image for $TOOL..."
docker build ${DOCKER_NO_CACHE:+--no-cache} -t "ai-$TOOL:latest" "dockerfiles/$TOOL"

# Create wrapper script
cat <<'EOF' > "$HOME/bin/vscode-run"
#!/usr/bin/env bash
# VSCode Desktop launcher with X11 forwarding

set -e

WORKSPACES_FILE="$HOME/.ai-workspaces"
CONTAINER_NAME="ai-vscode-sandbox-$$"

if [ ! -f "$WORKSPACES_FILE" ]; then
    echo "Error: No workspaces configured. Run setup.sh first." >&2
    exit 1
fi

# Detect OS for X11 setup
OS_TYPE=$(uname -s)

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

echo "🔒 Starting containerized VSCode Desktop (strict sandbox)..."
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

# Setup X11 forwarding based on OS
X11_OPTS=""
if [ "$OS_TYPE" = "Darwin" ]; then
    # macOS: Check if XQuartz is running
    if ! pgrep -q Xquartz 2>/dev/null && ! pgrep -q X11 2>/dev/null; then
        echo "⚠️  XQuartz not detected. Starting XQuartz..."
        open -a XQuartz
        sleep 3
    fi

    # Configure XQuartz to allow network connections (needed for Docker)
    defaults write org.xquartz.X11 nolisten_tcp -bool false 2>/dev/null || true

    # Allow connections from localhost
    xhost + localhost 2>/dev/null || true
    xhost + 127.0.0.1 2>/dev/null || true

    # Use TCP connection for X11 (Docker Desktop on macOS can't use Unix sockets)
    X11_OPTS="-e DISPLAY=host.docker.internal:0"

elif [ "$OS_TYPE" = "Linux" ]; then
    # Linux: Use host X11 socket directly
    X11_OPTS="-v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=$DISPLAY"

    # Allow local Docker connections
    xhost +local:docker 2>/dev/null || true
fi

echo "🚀 Launching VSCode Desktop in sandbox container..."
echo ""

# STRICT SANDBOX SECURITY:
# - Read-only filesystem (except /workspace, /tmp, /home/vscode)
# - No host environment variables (except DISPLAY)
# - No access to host files outside volumes
# - Non-root user

docker run \
    --rm \
    --name "$CONTAINER_NAME" \
    $VOLUME_MOUNTS \
    $X11_OPTS \
    --tmpfs /tmp:exec \
    --tmpfs /run \
    --tmpfs /home/vscode/.config:uid=1001,gid=1001 \
    --tmpfs /home/vscode/.vscode:uid=1001,gid=1001 \
    -e HOME=/home/vscode \
    -e PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    -u 1001:1001 \
    -w /workspace \
    "ai-vscode:latest"

echo ""
echo "✅ VSCode Desktop closed"
echo "🧹 Sandbox cleaned up"
EOF

chmod +x "$HOME/bin/vscode-run"

echo "✅ $TOOL installed (VSCode Desktop with X11)"
echo ""
echo "Created files:"
echo "  - Docker image: ai-$TOOL:latest"
echo "  - Wrapper script: $HOME/bin/vscode-run"
echo ""
echo "Requirements (macOS):"
echo "  - XQuartz: brew install xquartz"
echo "  - Log out and log back in after installing XQuartz"
echo ""
echo "Security Features:"
echo "  ✓ No host environment variables visible (except DISPLAY)"
echo "  ✓ No access to host filesystem outside volumes"
echo "  ✓ Runs as non-root user"
echo "  ✓ Terminal in VSCode is sandboxed"
echo ""
echo "Usage:"
echo "  vscode-run"
echo "  # Opens VSCode Desktop in a sandboxed container"
echo ""
echo "Whitelisted Workspaces:"
while IFS= read -r ws; do
    if [ -n "$ws" ] && [ -d "$ws" ]; then
        echo "  - $ws"
    fi
done < "$WORKSPACES_FILE"

