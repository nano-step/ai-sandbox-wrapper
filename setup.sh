#!/usr/bin/env bash
set -e

for arg in "$@"; do
  case "$arg" in
    --no-cache) export DOCKER_NO_CACHE=1 ;;
  esac
done

# Interactive multi-select menu
# Usage: multi_select "title" "comma,separated,options" "comma,separated,descriptions"
# Returns: SELECTED_ITEMS as an array
multi_select() {
  local title="$1"
  IFS=',' read -ra options <<< "$2"
  IFS=',' read -ra descriptions <<< "$3"
  local preselected="${4:-}"
  local cursor=0
  local selected=()
  for ((i=0; i<${#options[@]}; i++)); do
    if [[ -n "$preselected" ]] && echo ",$preselected," | grep -q ",${options[$i]},"; then
      selected[i]=1
    else
      selected[i]=0
    fi
  done

  # Use tput for better terminal control
  tput civis # Hide cursor
  trap 'tput cnorm; exit' INT TERM # Show cursor on exit

  while true; do
    clear
    echo "🚀 $title"
    echo "Use ARROWS to move, SPACE to toggle, ENTER to confirm"
    echo ""

    for i in "${!options[@]}"; do
      if [ "$i" -eq "$cursor" ]; then
        prefix="➔ "
        tput setaf 6 # Cyan
      else
        prefix="  "
      fi

      if [ "${selected[$i]}" -eq 1 ]; then
        check="[x]"
        tput setaf 2 # Green
      else
        check="[ ]"
      fi

      printf "%s %s %-12s - %s\n" "$prefix" "$check" "${options[$i]}" "${descriptions[$i]}"
      tput sgr0 # Reset colors
    done

    # Handle input
    IFS= read -rsn1 key

    # Handle escape sequences for arrows
    if [[ "$key" == $'\x1b' ]]; then
      # Read next two chars of the escape sequence
      read -rsn1 -t 1 next1
      read -rsn1 -t 1 next2
      case "$next1$next2" in
        '[A') ((cursor--)) || true ;; # Up
        '[B') ((cursor++)) || true ;; # Down
      esac
    else
      case "$key" in
        k) ((cursor--)) || true ;; # k for Up
        j) ((cursor++)) || true ;; # j for Down
        " ") # Space (toggle)
          if [ "${selected[$cursor]}" -eq 1 ]; then
            selected[$cursor]=0
          else
            selected[$cursor]=1
          fi
          ;;
        "") # Enter (newline/carriage return/empty string)
          break
          ;;
        $'\n'|$'\r') # Extra safety for different enter signals
          break
          ;;
      esac
    fi

    # Keep cursor in bounds
    if [ "$cursor" -lt 0 ]; then cursor=$((${#options[@]} - 1)); fi
    if [ "$cursor" -ge "${#options[@]}" ]; then cursor=0; fi
  done

  tput cnorm # Show cursor

  # Prepare result
  SELECTED_ITEMS=()
  for i in "${!options[@]}"; do
    if [ "${selected[$i]}" -eq 1 ]; then
      SELECTED_ITEMS+=("${options[$i]}")
    fi
  done
}

# Interactive single-select menu
# Usage: single_select "title" "comma,separated,options" "comma,separated,descriptions"
# Returns: SELECTED_ITEM as a string
single_select() {
  local title="$1"
  IFS=',' read -ra options <<< "$2"
  IFS=',' read -ra descriptions <<< "$3"
  local cursor=0

  tput civis # Hide cursor
  trap 'tput cnorm; exit' INT TERM

  while true; do
    clear
    echo "🚀 $title"
    echo "Use ARROWS to move, ENTER to select"
    echo ""

    for i in "${!options[@]}"; do
      if [ "$i" -eq "$cursor" ]; then
        prefix="➔ "
        tput setaf 6 # Cyan
      else
        prefix="  "
      fi

      printf "%s %-12s - %s\n" "$prefix" "${options[$i]}" "${descriptions[$i]}"
      tput sgr0
    done

    IFS= read -rsn1 key
    if [[ "$key" == $'\x1b' ]]; then
      read -rsn1 -t 1 next1
      read -rsn1 -t 1 next2
      case "$next1$next2" in
        '[A') ((cursor--)) || true ;;
        '[B') ((cursor++)) || true ;;
      esac
    else
      case "$key" in
        k) ((cursor--)) || true ;;
        j) ((cursor++)) || true ;;
        "") break ;;
        $'\n'|$'\r') break ;;
      esac
    fi

    if [ "$cursor" -lt 0 ]; then cursor=$((${#options[@]} - 1)); fi
    if [ "$cursor" -ge "${#options[@]}" ]; then cursor=0; fi
  done

  tput cnorm
  SELECTED_ITEM="${options[$cursor]}"
}

# Check and install dependencies
echo "Checking and installing dependencies..."

if ! command -v git &> /dev/null; then
    echo "Installing git..."
    apt-get update && apt-get install -y git
fi

if ! command -v python3 &> /dev/null; then
    echo "Installing python3..."
    apt-get install -y python3 python3-pip
fi

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker Desktop first."
    exit 1
fi

echo "🚀 AI Sandbox Setup (Docker Desktop + Node 22 LTS)"

# Consolidated config directory
SANDBOX_DIR="$HOME/.ai-sandbox"
mkdir -p "$SANDBOX_DIR"

WORKSPACES_FILE="$SANDBOX_DIR/workspaces"

# Handle whitelisted workspaces
WORKSPACES=()

if [[ -f "$WORKSPACES_FILE" ]]; then
  echo "Existing whitelisted workspaces found:"
  while IFS= read -r line; do
    if [[ -n "$line" ]]; then
      echo "  - $line"
      WORKSPACES+=("$line")
    fi
  done < "$WORKSPACES_FILE"

  echo ""
  single_select "Configure Workspaces" "reuse,add,replace" "Keep existing whitelisted folders,Append new folders to the list,Start fresh with new folders"

  case "$SELECTED_ITEM" in
    add)
      echo "Enter additional workspace directories (comma-separated):"
      read -p "Add Workspaces: " WORKSPACE_INPUT
      ;;
    replace)
      WORKSPACES=()
      echo "Enter new workspace directories (comma-separated):"
      read -p "Workspaces: " WORKSPACE_INPUT
      ;;
    *)
      WORKSPACE_INPUT=""
      ;;
  esac
else
  echo "Enter workspace directories to whitelist (comma-separated):"
  echo "Example: $HOME/projects, $HOME/code, /opt/work"
  read -p "Workspaces: " WORKSPACE_INPUT
fi

# Parse and validate new workspaces if provided
if [[ -n "$WORKSPACE_INPUT" ]]; then
  IFS=',' read -ra WORKSPACE_ARRAY <<< "$WORKSPACE_INPUT"
  for ws in "${WORKSPACE_ARRAY[@]}"; do
    ws=$(echo "$ws" | xargs)  # trim whitespace
    ws="${ws/#\~/$HOME}"      # expand ~ to $HOME
    if [[ -n "$ws" ]]; then
      mkdir -p "$ws"
      # Avoid duplicates
      if [[ ! " ${WORKSPACES[*]} " =~ " ${ws} " ]]; then
        WORKSPACES+=("$ws")
      fi
    fi
  done
fi

if [[ ${#WORKSPACES[@]} -eq 0 ]]; then
  echo "ℹ️  No workspaces whitelisted yet. You can whitelist folders on-demand when running tools."
fi

# Save workspaces to legacy config file (for backward compatibility)
printf "%s\n" "${WORKSPACES[@]}" > "$WORKSPACES_FILE"
chmod 600 "$WORKSPACES_FILE"

# Generate v2 config.json
CONFIG_JSON="$SANDBOX_DIR/config.json"
if command -v jq &>/dev/null; then
  # Build workspaces JSON array
  WS_JSON="[]"
  for ws in "${WORKSPACES[@]}"; do
    WS_JSON=$(echo "$WS_JSON" | jq --arg w "$ws" '. + [$w]')
  done

  if [[ -f "$CONFIG_JSON" ]]; then
    # Merge with existing config (preserve networks, git settings)
    jq --argjson ws "$WS_JSON" '.version = 2 | .workspaces = $ws | .git = (.git // {"allowedWorkspaces":[],"keySelections":{}}) | .networks = (.networks // {"global":[],"workspaces":{}})' "$CONFIG_JSON" > "$CONFIG_JSON.tmp" \
      && mv "$CONFIG_JSON.tmp" "$CONFIG_JSON"
  else
    # Create new v2 config
    echo "{\"version\":2,\"workspaces\":$WS_JSON,\"git\":{\"allowedWorkspaces\":[],\"keySelections\":{}},\"networks\":{\"global\":[],\"workspaces\":{}}}" | jq . > "$CONFIG_JSON"
  fi
  chmod 600 "$CONFIG_JSON"
  echo "📁 Configuration saved to: $CONFIG_JSON"
else
  # No jq - create basic config
  WS_JSON="["
  first=true
  for ws in "${WORKSPACES[@]}"; do
    if $first; then first=false; else WS_JSON="$WS_JSON,"; fi
    WS_JSON="$WS_JSON\"$ws\""
  done
  WS_JSON="$WS_JSON]"
  echo "{\"version\":2,\"workspaces\":$WS_JSON,\"git\":{\"allowedWorkspaces\":[],\"keySelections\":{}},\"networks\":{\"global\":[],\"workspaces\":{}}}" > "$CONFIG_JSON"
  chmod 600 "$CONFIG_JSON"
  echo "📁 Configuration saved to: $CONFIG_JSON"
fi
echo "📁 Legacy workspaces file: $WORKSPACES_FILE"

# Use first workspace as default for backwards compatibility
WORKSPACE="${WORKSPACES[0]}"

# Tool definitions
TOOL_OPTIONS="amp,opencode,openclaw,open-design,droid,claude,gemini,kilo,qwen,codex,qoder,auggie,codebuddy,jules,shai"
TOOL_DESCS="AI coding assistant from @sourcegraph/amp,Open-source coding tool from opencode-ai,OpenClaw AI gateway (Docker Compose),Open Design daemon (HTTP service — agent-driven design generation),Factory CLI from factory.ai,Claude Code CLI from Anthropic,Google Gemini CLI (free tier),AI pair programmer (Git-native),Kilo Code (500+ models),Alibaba Qwen CLI (1M context),OpenAI Codex terminal agent,Qoder AI CLI assistant,Augment Auggie CLI,Tencent CodeBuddy CLI,Google Jules CLI,OVHcloud SHAI agent"

# Pre-select previously installed tools
PRESELECTED_TOOLS=""
if command -v jq &>/dev/null && [[ -f "$SANDBOX_DIR/config.json" ]]; then
  PRESELECTED_TOOLS=$(jq -r '.tools.installed // [] | join(",")' "$SANDBOX_DIR/config.json" 2>/dev/null || echo "")
fi

# Interactive multi-select
multi_select "Select AI Tools to Install" "$TOOL_OPTIONS" "$TOOL_DESCS" "$PRESELECTED_TOOLS"
TOOLS=("${SELECTED_ITEMS[@]}")

if [[ ${#TOOLS[@]} -eq 0 ]]; then
  echo "❌ No tools selected for installation"
  exit 0
fi

echo "Installing tools: ${TOOLS[*]}"

CONTAINERIZED_TOOLS=()
for tool in "${TOOLS[@]}"; do
  if [[ "$tool" =~ ^(amp|opencode|openclaw|open-design|claude|aider|droid|gemini|kilo|qwen|codex|qoder|auggie|codebuddy|jules|shai)$ ]]; then
    CONTAINERIZED_TOOLS+=("$tool")
  fi
done

echo ""
if [[ ${#CONTAINERIZED_TOOLS[@]} -gt 0 ]]; then
  # Category 1: AI Enhancement Tools (spec-driven development, UI/UX, browser automation)
  AI_TOOL_OPTIONS="spec-kit,ux-ui-promax,openspec,playwright,rtk,pup,open-design"
  AI_TOOL_DESCS="Spec-driven development toolkit,UI/UX design intelligence tool,OpenSpec - spec-driven development,Browser automation + Chromium/Firefox/WebKit (~500MB),RTK token optimizer - reduces LLM token usage by 60-90% (~5MB),Datadog Pup CLI - AI-agent-ready observability CLI (~10MB),Open Design daemon - AI design generation service (port 7456)"

  multi_select "Select AI Enhancement Tools (installed in containers)" "$AI_TOOL_OPTIONS" "$AI_TOOL_DESCS"
  AI_ENHANCEMENT_TOOLS=("${SELECTED_ITEMS[@]}")

  if [[ ${#AI_ENHANCEMENT_TOOLS[@]} -gt 0 ]]; then
    echo "AI tools selected: ${AI_ENHANCEMENT_TOOLS[*]}"
  fi

  echo ""

  # Category 2: Language Runtimes (Ruby, Go, etc.)
  LANG_OPTIONS="ruby,go"
  LANG_DESCS="Ruby 3.3.0 + Rails 8.0.2 via rbenv (~500MB),Go 1.23.0 + sqlc + goose + golangci-lint (~250MB)"

  multi_select "Select Additional Language Runtimes (installed in containers)" "$LANG_OPTIONS" "$LANG_DESCS"
  LANGUAGE_RUNTIMES=("${SELECTED_ITEMS[@]}")

  if [[ ${#LANGUAGE_RUNTIMES[@]} -gt 0 ]]; then
    echo "Language runtimes selected: ${LANGUAGE_RUNTIMES[*]}"
  fi

  echo ""

  # Category 3: MCP Tools (Browser automation for AI agents)
  MCP_OPTIONS="chrome-devtools-mcp,playwright-mcp,chrome-devtools-mcp-host,playwright-mcp-host"
  MCP_DESCS="Google Chrome DevTools MCP - performance profiling + debugging (~400MB),Microsoft Playwright MCP - multi-browser automation (~300MB),Chrome DevTools MCP via host Chrome - no container Chromium (~30MB),Playwright MCP via host Chrome - no container Chromium (~30MB)"

  multi_select "Select MCP Tools for AI Agent Browser Automation" "$MCP_OPTIONS" "$MCP_DESCS"
  MCP_TOOLS=("${SELECTED_ITEMS[@]}")

  if [[ ${#MCP_TOOLS[@]} -gt 0 ]]; then
    echo "MCP tools selected: ${MCP_TOOLS[*]}"
  fi

  # Combine all categories for processing
  ADDITIONAL_TOOLS=("${AI_ENHANCEMENT_TOOLS[@]}" "${LANGUAGE_RUNTIMES[@]}" "${MCP_TOOLS[@]}")
else
  ADDITIONAL_TOOLS=()
  echo "ℹ️  No containerized AI tools selected. Skipping additional tools."
fi

mkdir -p "$WORKSPACE"
mkdir -p "$HOME/bin"

# Secrets
ENV_FILE="$SANDBOX_DIR/env"
if [ ! -f "$ENV_FILE" ]; then
  cat <<EOF > "$ENV_FILE"
OPENAI_API_KEY=[REDACTED:api-key]
ANTHROPIC_API_KEY=[REDACTED:api-key]
EOF
  chmod 600 "$ENV_FILE"
  echo "⚠️  Edit $ENV_FILE with your real API keys"
fi

# Get script directory (supports both direct execution and npx)
if [[ -n "$AI_SANDBOX_ROOT" ]]; then
  SCRIPT_DIR="$AI_SANDBOX_ROOT"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Install base image if any containerized tools or additional tools selected
NEEDS_BASE_IMAGE=0
if [[ ${#CONTAINERIZED_TOOLS[@]} -gt 0 || ${#ADDITIONAL_TOOLS[@]} -gt 0 ]]; then
  NEEDS_BASE_IMAGE=1
fi

if [[ $NEEDS_BASE_IMAGE -eq 1 ]]; then
  INSTALL_SPEC_KIT="${INSTALL_SPEC_KIT:-0}"
  INSTALL_UX_UI_PROMAX="${INSTALL_UX_UI_PROMAX:-0}"
  INSTALL_OPENSPEC="${INSTALL_OPENSPEC:-0}"
  INSTALL_PLAYWRIGHT="${INSTALL_PLAYWRIGHT:-0}"
  INSTALL_RUBY="${INSTALL_RUBY:-0}"
  INSTALL_GO="${INSTALL_GO:-0}"
  INSTALL_CHROME_DEVTOOLS_MCP="${INSTALL_CHROME_DEVTOOLS_MCP:-0}"
  INSTALL_PLAYWRIGHT_MCP="${INSTALL_PLAYWRIGHT_MCP:-0}"
  INSTALL_RTK="${INSTALL_RTK:-0}"
  INSTALL_PUP="${INSTALL_PUP:-0}"
  INSTALL_OPEN_DESIGN="${INSTALL_OPEN_DESIGN:-0}"

  for addon in "${ADDITIONAL_TOOLS[@]}"; do
    case "$addon" in
      spec-kit)
        INSTALL_SPEC_KIT=1
        ;;
      ux-ui-promax)
        INSTALL_UX_UI_PROMAX=1
        ;;
      openspec)
        INSTALL_OPENSPEC=1
        ;;
      playwright)
        INSTALL_PLAYWRIGHT=1
        ;;
      ruby)
        INSTALL_RUBY=1
        ;;
      go)
        INSTALL_GO=1
        ;;
      chrome-devtools-mcp)
        INSTALL_CHROME_DEVTOOLS_MCP=1
        ;;
      playwright-mcp)
        INSTALL_PLAYWRIGHT_MCP=1
        ;;
      chrome-devtools-mcp-host)
        INSTALL_CHROME_DEVTOOLS_MCP=1
        INSTALL_PLAYWRIGHT_HOST=1
        ;;
      playwright-mcp-host)
        INSTALL_PLAYWRIGHT_MCP=1
        INSTALL_PLAYWRIGHT_HOST=1
        ;;
      rtk)
        INSTALL_RTK=1
        ;;
      pup)
        INSTALL_PUP=1
        ;;
      open-design)
        INSTALL_OPEN_DESIGN=1
        ;;
    esac
  done

  export INSTALL_SPEC_KIT INSTALL_UX_UI_PROMAX INSTALL_OPENSPEC INSTALL_PLAYWRIGHT INSTALL_RUBY INSTALL_GO INSTALL_CHROME_DEVTOOLS_MCP INSTALL_PLAYWRIGHT_MCP INSTALL_PLAYWRIGHT_HOST INSTALL_RTK INSTALL_PUP INSTALL_OPEN_DESIGN
  
  # Save MCP selections to ~/.ai-sandbox/config.json for ai-run auto-configuration
  SANDBOX_CONFIG="$HOME/.ai-sandbox/config.json"
  mkdir -p "$HOME/.ai-sandbox"
  if command -v jq &>/dev/null; then
    if [[ ! -f "$SANDBOX_CONFIG" ]]; then
      echo '{"version":2,"workspaces":[],"git":{"allowedWorkspaces":[],"keySelections":{}},"networks":{"global":[],"workspaces":{}},"mcp":{"installed":[]}}' > "$SANDBOX_CONFIG"
    fi
    MCP_INSTALLED='[]'
    [[ "$INSTALL_CHROME_DEVTOOLS_MCP" -eq 1 ]] && MCP_INSTALLED=$(echo "$MCP_INSTALLED" | jq '. + ["chrome-devtools"]')
    [[ "$INSTALL_PLAYWRIGHT_MCP" -eq 1 ]] && MCP_INSTALLED=$(echo "$MCP_INSTALLED" | jq '. + ["playwright"]')
    jq --argjson mcp "$MCP_INSTALLED" '.mcp.installed = $mcp' "$SANDBOX_CONFIG" > "$SANDBOX_CONFIG.tmp" && mv "$SANDBOX_CONFIG.tmp" "$SANDBOX_CONFIG"
    chmod 600 "$SANDBOX_CONFIG"
    echo "✅ MCP tool selections saved to config"

    # Auto-detect host browser for ai-run's "Host Chrome CDP mode". That mode
    # is gated on .mcp.chromePath being set in config.json, but setup never
    # wrote it -- users had to manually edit the file. Detect a sensible
    # default the first time an MCP browser tool is selected; preserve any
    # existing value the user set themselves.
    if [[ "$INSTALL_CHROME_DEVTOOLS_MCP" -eq 1 || "$INSTALL_PLAYWRIGHT_MCP" -eq 1 ]]; then
      EXISTING_CHROME_PATH=$(jq -r '.mcp.chromePath // empty' "$SANDBOX_CONFIG" 2>/dev/null)
      if [[ -z "$EXISTING_CHROME_PATH" ]]; then
        DETECTED_CHROME_PATH=""
        case "$(uname -s)" in
          Darwin)
            # Stable Chrome first, then Chromium, then popular forks.
            for candidate in \
              "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
              "/Applications/Chromium.app/Contents/MacOS/Chromium" \
              "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" \
              "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
              "/Applications/Arc.app/Contents/MacOS/Arc"; do
              if [[ -f "$candidate" ]]; then
                DETECTED_CHROME_PATH="$candidate"
                break
              fi
            done
            ;;
          Linux)
            for cmd in google-chrome-stable google-chrome chromium chromium-browser brave-browser microsoft-edge; do
              if command -v "$cmd" &>/dev/null; then
                DETECTED_CHROME_PATH=$(command -v "$cmd")
                break
              fi
            done
            ;;
        esac

        if [[ -n "$DETECTED_CHROME_PATH" ]]; then
          jq --arg path "$DETECTED_CHROME_PATH" '.mcp.chromePath = $path' "$SANDBOX_CONFIG" > "$SANDBOX_CONFIG.tmp" \
            && mv "$SANDBOX_CONFIG.tmp" "$SANDBOX_CONFIG"
          chmod 600 "$SANDBOX_CONFIG"
          echo "🌐 Host browser detected for CDP: $DETECTED_CHROME_PATH"
          echo "   (ai-run will launch this with --remote-debugging-port for MCP browser tools.)"
          echo "   To change or disable, edit .mcp.chromePath in $SANDBOX_CONFIG"
        else
          echo "ℹ️  No host browser auto-detected for CDP mode."
          echo "   To enable, set .mcp.chromePath in $SANDBOX_CONFIG to a Chrome/Chromium binary."
        fi
      fi
    fi
  fi
fi

TOOLS_CSV=$(IFS=','; echo "${TOOLS[*]}")
TOOLS="$TOOLS_CSV" \
  INSTALL_SPEC_KIT="$INSTALL_SPEC_KIT" \
  INSTALL_UX_UI_PROMAX="$INSTALL_UX_UI_PROMAX" \
  INSTALL_OPENSPEC="$INSTALL_OPENSPEC" \
  INSTALL_PLAYWRIGHT="$INSTALL_PLAYWRIGHT" \
  INSTALL_RUBY="$INSTALL_RUBY" \
  INSTALL_CHROME_DEVTOOLS_MCP="$INSTALL_CHROME_DEVTOOLS_MCP" \
  INSTALL_PLAYWRIGHT_MCP="$INSTALL_PLAYWRIGHT_MCP" \
  INSTALL_PLAYWRIGHT_HOST="$INSTALL_PLAYWRIGHT_HOST" \
  INSTALL_RTK="$INSTALL_RTK" \
  INSTALL_PUP="$INSTALL_PUP" \
  bash "$SCRIPT_DIR/lib/build-sandbox.sh"

# Install open-design as a separate daemon container (not part of sandbox image)
if [[ "${INSTALL_OPEN_DESIGN:-0}" -eq 1 ]]; then
  bash "$SCRIPT_DIR/lib/install-open-design.sh"
fi

OLD_IMAGES=()
for tool in "${TOOLS[@]}"; do
  if docker image inspect "ai-${tool}:latest" &>/dev/null; then
    OLD_IMAGES+=("ai-${tool}:latest")
  fi
done

if [[ ${#OLD_IMAGES[@]} -gt 0 ]]; then
  echo ""
  echo "🧹 Found old per-tool images that are no longer needed:"
  for img in "${OLD_IMAGES[@]}"; do
    echo "  - $img"
  done
  if [[ -t 0 ]]; then
    read -p "Remove old images to free disk space? [y/N]: " CLEANUP_CHOICE
    if [[ "$CLEANUP_CHOICE" =~ ^[Yy]$ ]]; then
      docker rmi "${OLD_IMAGES[@]}" 2>/dev/null || true
      echo "✅ Old images removed"
    fi
  fi
fi

# Additional tools are installed in base image (no host installation)

# Generate ai-run wrapper
bash "$SCRIPT_DIR/lib/generate-ai-run.sh"

# PATH + aliases
SHELL_RC="$HOME/.zshrc"

# Add PATH if not already present
if ! grep -q 'export PATH="\$HOME/bin:\$PATH"' "$SHELL_RC" 2>/dev/null; then
  echo "export PATH=\"\$HOME/bin:\$PATH\"" >> "$SHELL_RC"
fi

# Add aliases for each tool (only if not already present)
for tool in "${TOOLS[@]}"; do
  if ! grep -q "alias $tool=" "$SHELL_RC" 2>/dev/null; then
    echo "alias $tool=\"ai-run $tool\"" >> "$SHELL_RC"
  fi
done

if ! grep -q 'alias ai=' "$SHELL_RC" 2>/dev/null; then
  echo 'alias ai="ai-run"' >> "$SHELL_RC"
fi

# Additional tools don't need host aliases (only in containers)

# Verify permissions
if [[ ! -w "$SANDBOX_DIR" ]]; then
  echo "⚠️  WARNING: $SANDBOX_DIR is not writable. Attempting to fix permissions..."
  chmod -R u+w "$SANDBOX_DIR" 2>/dev/null || true
fi

echo "✅ Setup complete!"
echo ""
echo "🛠️  AI Sandbox built with tools:"
for tool in "${TOOLS[@]}"; do
  echo "  ai-run $tool (or: $tool)"
done
echo ""
echo "  ai-run (or: ai)  → Interactive shell with all tools"
echo ""
echo "📦 Image: ai-sandbox:latest"

if [[ ${#ADDITIONAL_TOOLS[@]} -gt 0 ]]; then
  echo ""
  echo "🔧 Additional tools (available inside all containerized AI tools):"
  for addon in "${ADDITIONAL_TOOLS[@]}"; do
    case $addon in
      spec-kit)
        echo "  specify - Spec-driven development toolkit"
        ;;
      ux-ui-promax)
        echo "  uipro - UI/UX design intelligence tool"
        ;;
      openspec)
        echo "  openspec - OpenSpec CLI for spec-driven development"
        ;;
      chrome-devtools-mcp)
        echo "  chrome-devtools-mcp - Google Chrome DevTools MCP server"
        ;;
      playwright-mcp)
        echo "  @playwright/mcp - Microsoft Playwright MCP server"
        ;;
      rtk)
        echo "  rtk - Token optimizer for AI coding agents (60-90% savings)"
        ;;
      open-design)
        echo "  open-design - AI design generation daemon (port 7456)"
        ;;
    esac
  done
fi
echo ""
echo "➡ Restart terminal or run: source ~/.zshrc"
echo "➡ Add API keys to: $ENV_FILE"
echo ""
echo "📁 Whitelisted workspaces:"
for ws in "${WORKSPACES[@]}"; do
  echo "  $ws"
done
echo ""
echo "💡 Manage workspaces in: $WORKSPACES_FILE"
echo "   Add folder:    echo '/path/to/folder' >> $WORKSPACES_FILE"
echo "   Remove folder: Edit $WORKSPACES_FILE and delete the line"
echo "   List folders:  cat $WORKSPACES_FILE"
echo ""
echo "📁 Per-project configs supported:"
for tool in "${TOOLS[@]}"; do
  echo "  .$tool.json (overrides global config in $HOME/.config/$tool or $HOME/.$tool)"
done
