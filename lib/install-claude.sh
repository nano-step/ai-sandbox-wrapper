#!/usr/bin/env bash
set -e

dockerfile_snippet() {
  cat <<'SNIPPET'
USER root
RUN export HOME=/root && curl -fsSL https://claude.ai/install.sh | bash && \
    mkdir -p /usr/local/share && \
    mv /root/.local/share/claude /usr/local/share/claude && \
    ln -sf /usr/local/share/claude/versions/$(ls /usr/local/share/claude/versions | head -1) /usr/local/bin/claude
USER agent
SNIPPET
}

if [[ "${SNIPPET_MODE:-}" == "1" ]]; then
  return 0 2>/dev/null || exit 0
fi

TOOL="claude"

echo "Installing $TOOL (Anthropic Claude Code - Native Binary)..."

# Create directories
mkdir -p "dockerfiles/$TOOL"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home/.cache"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home"

# Create Dockerfile using official native installer (no npm needed)
cat <<'EOF' > "dockerfiles/$TOOL/Dockerfile"
FROM ai-base:latest

USER root
# Install Claude Code using official native installer
RUN export HOME=/root && curl -fsSL https://claude.ai/install.sh | bash && \
    mkdir -p /usr/local/share && \
    mv /root/.local/share/claude /usr/local/share/claude && \
    ln -sf /usr/local/share/claude/versions/$(ls /usr/local/share/claude/versions | head -1) /usr/local/bin/claude

USER agent
ENTRYPOINT ["claude"]
EOF

# Build image
echo "Building Docker image for $TOOL (native binary)..."
docker build ${DOCKER_NO_CACHE:+--no-cache} --network=host -t "ai-$TOOL:latest" "dockerfiles/$TOOL"

echo "✅ $TOOL installed (Native Binary)"
echo ""
echo "Features:"
echo "  ✓ Official native binary"
echo "  ✓ Claude 3.5 Sonnet/Opus models"
echo "  ✓ Agentic coding with file editing"
echo "  ✓ Web search and fetch built-in"
echo ""
echo "Usage: ai-run claude"
echo "Auth: Set ANTHROPIC_API_KEY in ~/.ai-sandbox/env"
echo ""
