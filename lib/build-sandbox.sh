#!/usr/bin/env bash
set -e

TOOLS="${TOOLS:-}"
if [[ -z "$TOOLS" ]]; then
  echo "❌ No tools selected. Set TOOLS=tool1,tool2,..."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

SANDBOX_DIR="dockerfiles/sandbox"
mkdir -p "$SANDBOX_DIR"

echo "🔄 Generating unified sandbox Dockerfile..."
echo "   Tools: $TOOLS"

GENERATE_ONLY=1 INSTALL_RTK="${INSTALL_RTK:-0}" \
  INSTALL_PLAYWRIGHT_MCP="${INSTALL_PLAYWRIGHT_MCP:-0}" \
  INSTALL_CHROME_DEVTOOLS_MCP="${INSTALL_CHROME_DEVTOOLS_MCP:-0}" \
  INSTALL_PLAYWRIGHT="${INSTALL_PLAYWRIGHT:-0}" \
  INSTALL_RUBY="${INSTALL_RUBY:-0}" \
  INSTALL_SPEC_KIT="${INSTALL_SPEC_KIT:-0}" \
  INSTALL_UX_UI_PROMAX="${INSTALL_UX_UI_PROMAX:-0}" \
  INSTALL_OPENSPEC="${INSTALL_OPENSPEC:-0}" \
  bash "$SCRIPT_DIR/install-base.sh"

BASE_DOCKERFILE="dockerfiles/base/Dockerfile"
if [[ ! -f "$BASE_DOCKERFILE" ]]; then
  echo "❌ Base Dockerfile not found at $BASE_DOCKERFILE"
  exit 1
fi

BASE_CONTENT=$(cat "$BASE_DOCKERFILE")
BASE_PREAMBLE=$(echo "$BASE_CONTENT" | sed '/^USER agent$/,$d')

{
  echo "$BASE_PREAMBLE"
  echo ""

  IFS=',' read -ra TOOL_ARRAY <<< "$TOOLS"
  for tool in "${TOOL_ARRAY[@]}"; do
    tool=$(echo "$tool" | tr -d ' ')
    INSTALL_SCRIPT="$SCRIPT_DIR/install-${tool}.sh"
    
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
      echo "⚠️  Warning: No install script for '$tool', skipping" >&2
      continue
    fi
    
    echo "# === $tool ===" 
    SNIPPET_MODE=1 source "$INSTALL_SCRIPT"
    dockerfile_snippet
    echo ""
  done

  echo "USER agent"
  echo "ENV HOME=/home/agent"
  echo "CMD [\"bash\"]"
} > "$SANDBOX_DIR/Dockerfile"

if [[ -d "dockerfiles/base/skills" ]]; then
  cp -r "dockerfiles/base/skills" "$SANDBOX_DIR/"
fi

echo "✅ Dockerfile generated at $SANDBOX_DIR/Dockerfile"

echo "🔨 Building ai-sandbox:latest..."
HOST_UID=$(id -u)
docker build ${DOCKER_NO_CACHE:+--no-cache} \
  --build-arg AGENT_UID="${HOST_UID}" \
  -t "ai-sandbox:latest" "$SANDBOX_DIR"

echo "✅ ai-sandbox:latest built successfully"

SANDBOX_CONFIG="$HOME/.ai-sandbox/config.json"
if command -v jq &>/dev/null && [[ -f "$SANDBOX_CONFIG" ]]; then
  TOOLS_JSON=$(echo "$TOOLS" | tr ',' '\n' | jq -R . | jq -s .)
  jq --argjson tools "$TOOLS_JSON" '.tools.installed = $tools' "$SANDBOX_CONFIG" > "$SANDBOX_CONFIG.tmp" \
    && mv "$SANDBOX_CONFIG.tmp" "$SANDBOX_CONFIG"
  chmod 600 "$SANDBOX_CONFIG"
  echo "✅ Saved tools list to $SANDBOX_CONFIG"
fi

echo ""
echo "🎉 Sandbox ready with tools: $TOOLS"
echo "   Run: docker run --rm -it ai-sandbox:latest"
