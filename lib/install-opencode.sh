#!/usr/bin/env bash
set -e

dockerfile_snippet() {
  cat <<'SNIPPET'
USER root
RUN curl -fsSL https://opencode.ai/install | bash && \
    mv /root/.opencode/bin/opencode /usr/local/bin/opencode && \
    rm -rf /root/.opencode
SNIPPET
}

if [[ "${SNIPPET_MODE:-}" == "1" ]]; then
  return 0 2>/dev/null || exit 0
fi

TOOL="opencode"
OPENCODE_VERSION="${OPENCODE_VERSION:-}"

if [[ -n "$OPENCODE_VERSION" ]]; then
  echo "Installing $TOOL v$OPENCODE_VERSION (OpenCode AI - Native Go Binary)..."
else
  echo "Installing $TOOL (OpenCode AI - Native Go Binary, latest)..."
fi

mkdir -p "dockerfiles/$TOOL"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home/.cache"
mkdir -p "$HOME/.ai-sandbox/tools/$TOOL/home"

if [[ -n "$OPENCODE_VERSION" ]]; then
  cat > "dockerfiles/$TOOL/Dockerfile" <<EOF
FROM ai-base:latest

USER root
RUN curl -fsSL https://opencode.ai/install | bash -s -- --version $OPENCODE_VERSION && \\
    mv /root/.opencode/bin/opencode /usr/local/bin/opencode && \\
    rm -rf /root/.opencode

USER agent
ENTRYPOINT ["opencode"]
EOF
else
  cat <<'EOF' > "dockerfiles/$TOOL/Dockerfile"
FROM ai-base:latest

USER root
RUN curl -fsSL https://opencode.ai/install | bash && \
    mv /root/.opencode/bin/opencode /usr/local/bin/opencode && \
    rm -rf /root/.opencode

USER agent
ENTRYPOINT ["opencode"]
EOF
fi

# Build image
echo "Building Docker image for $TOOL (native binary)..."
docker build ${DOCKER_NO_CACHE:+--no-cache} -t "ai-$TOOL:latest" "dockerfiles/$TOOL"

echo "✅ $TOOL installed (Native Go Binary)"
echo ""
echo "Features:"
echo "  ✓ Native Go binary (no Node.js)"
echo "  ✓ Multi-model flexibility"
echo "  ✓ Terminal-based TUI workflow"
echo ""
echo "Usage: ai-run opencode"
