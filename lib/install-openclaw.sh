#!/usr/bin/env bash
set -e

# OpenClaw installer: Uses official Docker Compose setup
TOOL="openclaw"

echo "🔄 Installing $TOOL (OpenClaw - Official Docker Compose)..."

# Create directories
OPENCLAW_REPO_DIR="$HOME/.ai-sandbox/tools/$TOOL/repo"
mkdir -p "$OPENCLAW_REPO_DIR"
mkdir -p "$HOME/.openclaw"

# Clone OpenClaw repository if not exists
if [[ ! -d "$OPENCLAW_REPO_DIR/.git" ]]; then
  echo "📦 Cloning OpenClaw repository..."
  git clone https://github.com/openclaw/openclaw.git "$OPENCLAW_REPO_DIR"
else
  echo "📦 OpenClaw repository already exists, pulling latest..."
  cd "$OPENCLAW_REPO_DIR"
  git pull origin main || git pull origin master || true
fi

cd "$OPENCLAW_REPO_DIR"

# Build OpenClaw Docker image using their docker-compose
echo "🔨 Building OpenClaw Docker image..."
docker compose build

echo "✅ $TOOL installed (Docker Compose)"
echo ""
echo "Features:"
echo "  ✓ Official OpenClaw Docker setup"
echo "  ✓ Gateway mode (port 18789)"
echo "  ✓ Bridge mode (port 18790)"
echo "  ✓ Workspace whitelist integration"
echo ""
echo "Usage: ai-run openclaw"
echo "Config: ~/.openclaw/"
