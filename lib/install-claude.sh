#!/usr/bin/env bash
set -e

# Claude Code installer: Anthropic's AI coding agent (Native Binary)
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
# Install tmux for Agent Teams split-pane mode
RUN apt-get update && apt-get install -y --no-install-recommends tmux && rm -rf /var/lib/apt/lists/*

# Install CCS (Claude Code Switch) for multi-provider model switching
# Use --ignore-scripts to avoid postinstall failures when HOME=/home/agent but running as root
RUN npm install -g @kaitranntt/ccs --ignore-scripts && \
    mkdir -p /home/agent/.ccs && \
    chown -R agent:agent /home/agent/.ccs && \
    which ccs && ccs --version

# Install Claude Code using official native installer
RUN curl -fsSL https://claude.ai/install.sh | bash && \
    mkdir -p /usr/local/share && \
    mv /home/agent/.local/share/claude /usr/local/share/claude && \
    ln -sf /usr/local/share/claude/versions/$(ls /usr/local/share/claude/versions | head -1) /usr/local/bin/claude

USER agent
ENTRYPOINT ["claude"]
EOF

# Build image
echo "Building Docker image for $TOOL (native binary)..."
docker build ${DOCKER_NO_CACHE:+--no-cache} -t "ai-$TOOL:latest" "dockerfiles/$TOOL"

echo "✅ $TOOL installed (Native Binary)"
echo ""
echo "Features:"
echo "  ✓ Official native binary"
echo "  ✓ Claude 3.5 Sonnet/Opus models"
echo "  ✓ Agentic coding with file editing"
echo "  ✓ Web search and fetch built-in"
echo "  ✓ Agent Teams (multi-agent tmux split-pane workflows)"
echo "  ✓ CCS (Claude Code Switch) for multi-provider model switching"
echo ""
echo "Usage: ai-run claude"
echo "Auth: Set ANTHROPIC_API_KEY in ~/.ai-sandbox/env"
echo ""
echo "Agent Teams: Add CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 to ~/.ai-sandbox/env"
echo "CCS: Run 'ai-run claude --shell' then 'ccs help' to configure providers"
