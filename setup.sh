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
  local cursor=0
  local selected=()
  for ((i=0; i<${#options[@]}; i++)); do selected[i]=0; done

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
        '[A') ((cursor--)) ;; # Up
        '[B') ((cursor++)) ;; # Down
      esac
    else
      case "$key" in
        k) ((cursor--)) ;; # k for Up
        j) ((cursor++)) ;; # j for Down
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
        '[A') ((cursor--)) ;;
        '[B') ((cursor++)) ;;
      esac
    else
      case "$key" in
        k) ((cursor--)) ;;
        j) ((cursor++)) ;;
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
  echo "❌ No valid workspaces provided"
  exit 1
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
TOOL_OPTIONS="amp,opencode,droid,claude,gemini,kilo,qwen,codex,qoder,auggie,codebuddy,jules,shai,vscode,codeserver"
TOOL_DESCS="AI coding assistant from @sourcegraph/amp,Open-source coding tool from opencode-ai,Factory CLI from factory.ai,Claude Code CLI from Anthropic,Google Gemini CLI (free tier),AI pair programmer (Git-native),Kilo Code (500+ models),Alibaba Qwen CLI (1M context),OpenAI Codex terminal agent,Qoder AI CLI assistant,Augment Auggie CLI,Tencent CodeBuddy CLI,Google Jules CLI,OVHcloud SHAI agent,VSCode Desktop in Docker (X11),VSCode in browser (fast)"

# Interactive multi-select
multi_select "Select AI Tools to Install" "$TOOL_OPTIONS" "$TOOL_DESCS"
TOOLS=("${SELECTED_ITEMS[@]}")

if [[ ${#TOOLS[@]} -eq 0 ]]; then
  echo "❌ No tools selected for installation"
  exit 0
fi

echo "Installing tools: ${TOOLS[*]}"

CONTAINERIZED_TOOLS=()
for tool in "${TOOLS[@]}"; do
  if [[ "$tool" =~ ^(amp|opencode|claude|aider|droid|gemini|kilo|qwen|codex|qoder|auggie|codebuddy|jules|shai)$ ]]; then
    CONTAINERIZED_TOOLS+=("$tool")
  fi
done

echo ""
if [[ ${#CONTAINERIZED_TOOLS[@]} -gt 0 ]]; then
  # Category 1: AI Enhancement Tools (spec-driven development, UI/UX, browser automation)
  AI_TOOL_OPTIONS="spec-kit,ux-ui-promax,openspec,playwright"
  AI_TOOL_DESCS="Spec-driven development toolkit,UI/UX design intelligence tool,OpenSpec - spec-driven development,Browser automation + Chromium/Firefox/WebKit (~500MB)"

  multi_select "Select AI Enhancement Tools (installed in containers)" "$AI_TOOL_OPTIONS" "$AI_TOOL_DESCS"
  AI_ENHANCEMENT_TOOLS=("${SELECTED_ITEMS[@]}")

  if [[ ${#AI_ENHANCEMENT_TOOLS[@]} -gt 0 ]]; then
    echo "AI tools selected: ${AI_ENHANCEMENT_TOOLS[*]}"
  fi

  echo ""

  # Category 2: Language Runtimes (Ruby, etc.)
  LANG_OPTIONS="ruby"
  LANG_DESCS="Ruby 3.3.0 + Rails 8.0.2 via rbenv (~500MB)"

  multi_select "Select Additional Language Runtimes (installed in containers)" "$LANG_OPTIONS" "$LANG_DESCS"
  LANGUAGE_RUNTIMES=("${SELECTED_ITEMS[@]}")

  if [[ ${#LANGUAGE_RUNTIMES[@]} -gt 0 ]]; then
    echo "Language runtimes selected: ${LANGUAGE_RUNTIMES[*]}"
  fi

  # Combine both categories for processing
  ADDITIONAL_TOOLS=("${AI_ENHANCEMENT_TOOLS[@]}" "${LANGUAGE_RUNTIMES[@]}")
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

# Install base image if any containerized tools selected (vscode doesn't need it)
NEEDS_BASE_IMAGE=0
for tool in "${TOOLS[@]}"; do
  if [[ "$tool" =~ ^(amp|opencode|claude|aider)$ ]]; then
    NEEDS_BASE_IMAGE=1
    break
  fi
done

if [[ $NEEDS_BASE_IMAGE -eq 1 ]]; then
  INSTALL_SPEC_KIT=0
  INSTALL_UX_UI_PROMAX=0
  INSTALL_OPENSPEC=0
  INSTALL_PLAYWRIGHT=0
  INSTALL_RUBY=0

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
    esac
  done

  export INSTALL_SPEC_KIT INSTALL_UX_UI_PROMAX INSTALL_OPENSPEC INSTALL_PLAYWRIGHT INSTALL_RUBY
  bash "$SCRIPT_DIR/lib/install-base.sh"
fi

# Install selected tools
for tool in "${TOOLS[@]}"; do
  case $tool in
    amp)
      bash "$SCRIPT_DIR/lib/install-amp.sh"
      ;;
    opencode)
      bash "$SCRIPT_DIR/lib/install-opencode.sh"
      ;;
    droid)
      bash "$SCRIPT_DIR/lib/install-droid.sh"
      ;;
    claude)
      bash "$SCRIPT_DIR/lib/install-claude.sh"
      ;;
     gemini)
       bash "$SCRIPT_DIR/lib/install-gemini.sh"
       ;;
     aider)
       bash "$SCRIPT_DIR/lib/install-aider.sh"
       ;;
     kilo)
      bash "$SCRIPT_DIR/lib/install-kilo.sh"
      ;;
    qwen)
      bash "$SCRIPT_DIR/lib/install-qwen.sh"
      ;;
    codex)
      bash "$SCRIPT_DIR/lib/install-codex.sh"
      ;;
    qoder)
      bash "$SCRIPT_DIR/lib/install-qoder.sh"
      ;;
    auggie)
      bash "$SCRIPT_DIR/lib/install-auggie.sh"
      ;;
    codebuddy)
      bash "$SCRIPT_DIR/lib/install-codebuddy.sh"
      ;;
    jules)
      bash "$SCRIPT_DIR/lib/install-jules.sh"
      ;;
    shai)
      bash "$SCRIPT_DIR/lib/install-shai.sh"
      ;;
    vscode)
      bash "$SCRIPT_DIR/lib/install-vscode.sh"
      ;;
    codeserver)
      bash "$SCRIPT_DIR/lib/install-codeserver.sh"
      ;;
  esac
done

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
  if [[ "$tool" == "vscode" ]]; then
    if ! grep -q "alias vscode=" "$SHELL_RC" 2>/dev/null; then
      echo "alias vscode='vscode-run'" >> "$SHELL_RC"
    fi
  elif [[ "$tool" == "codeserver" ]]; then
    if ! grep -q "alias codeserver=" "$SHELL_RC" 2>/dev/null; then
      echo "alias codeserver='codeserver-run'" >> "$SHELL_RC"
    fi
  else
    if ! grep -q "alias $tool=" "$SHELL_RC" 2>/dev/null; then
      echo "alias $tool=\"ai-run $tool\"" >> "$SHELL_RC"
    fi
  fi
done

# Additional tools don't need host aliases (only in containers)

echo ""
echo "✅ Setup complete!"
echo ""
echo "🛠️  Installed AI tools:"
for tool in "${TOOLS[@]}"; do
  if [[ "$tool" == "vscode" ]]; then
    echo "  vscode-run (or: vscode) - Desktop VSCode via X11"
  elif [[ "$tool" == "codeserver" ]]; then
    echo "  codeserver-run (or: codeserver) - Browser VSCode at localhost:8080"
  else
    echo "  ai-run $tool (or: $tool)"
  fi
done

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
  if [[ "$tool" =~ ^(vscode|codeserver)$ ]]; then
    continue
  fi
  echo "  .$tool.json (overrides global config in $HOME/.config/$tool or $HOME/.$tool)"
done
