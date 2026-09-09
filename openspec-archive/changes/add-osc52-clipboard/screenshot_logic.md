# Screenshot Directory Whitelisting Logic

## Where to implement
`bin/ai-run` (lines 331+, after workspace validation)

## Rationale
- Needs to happen at runtime (so it catches config changes)
- Should only happen in interactive mode (TTY)
- Should check if the directory is already whitelisted to avoid spamming the user

## Implementation Code

```bash
# ============================================================================
# SCREENSHOT DIRECTORY DETECTION
# ============================================================================

# Only check on macOS and interactive mode
if [[ "$(uname)" == "Darwin" ]] && [[ -t 0 ]]; then
  # 1. Detect location
  SCREENSHOT_DIR=$(defaults read com.apple.screencapture location 2>/dev/null || echo "$HOME/Desktop")
  # Expand tilde if present
  SCREENSHOT_DIR="${SCREENSHOT_DIR/#\~/$HOME}"

  # 2. Check if valid directory
  if [[ -d "$SCREENSHOT_DIR" ]]; then
    
    # 3. Check if ALREADY whitelisted (exact match or subdirectory)
    IS_WHITELISTED=false
    while IFS= read -r ws; do
      if [[ "$SCREENSHOT_DIR" == "$ws"* ]] || [[ "$ws" == "$SCREENSHOT_DIR"* ]]; then
        IS_WHITELISTED=true
        break
      fi
    done < <(read_workspaces)

    # 4. Prompt if not whitelisted
    if [[ "$IS_WHITELISTED" == "false" ]]; then
      echo ""
      echo "📸 Screenshot Directory Detected"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "Location: $SCREENSHOT_DIR"
      echo "Status:   Not whitelisted"
      echo ""
      echo "Whitelisting this folder allows you to drag & drop screenshots into AI tools."
      echo ""
      read -p "Whitelist screenshots folder? [y/N]: " CONFIRM_SS
      
      if [[ "$CONFIRM_SS" =~ ^[Yy]$ ]]; then
        add_workspace "$SCREENSHOT_DIR"
        echo "✅ Added to whitelist."
        # Refresh workspace list for current run
        VOLUME_MOUNTS="$VOLUME_MOUNTS -v $SCREENSHOT_DIR:$SCREENSHOT_DIR:delegated"
      else
        # Optional: Save a "ignore" preference so we don't ask again?
        # For now, just skip.
        echo "❌ Skipped."
      fi
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
  fi
fi
```
