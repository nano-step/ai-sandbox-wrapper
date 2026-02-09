# Clipboard Support Guide

The AI Sandbox runs tools inside Docker containers, which don't have direct access to your system clipboard. This guide explains how clipboard works and which terminals are supported.

## How Clipboard Works

There are two methods for clipboard access in containers:

| Method | How It Works | Requirements |
|--------|--------------|--------------|
| **OSC52** (Recommended) | Terminal intercepts escape sequences and handles clipboard | Terminal must support OSC52 |
| **X11 Forwarding** | Container connects to host's X11 display server | X11 server running (XQuartz on macOS) |

**OSC52 is preferred** because it:
- Works without additional setup
- No security risk of X11 socket exposure
- Works over SSH and in containers automatically

## Terminal Compatibility

### ✅ Full Support (OSC52)

These terminals support OSC52 clipboard - **copy/paste works out of the box**:

| Terminal | Platform | Notes |
|----------|----------|-------|
| **iTerm2** | macOS | Gold standard, best support |
| **Warp** | macOS | Confirmed working |
| **Kitty** | Cross-platform | Advanced extensions (OSC 5522) |
| **Alacritty** | Cross-platform | GPU-accelerated |
| **WezTerm** | Cross-platform | Highly configurable |
| **Ghostty** | macOS/Linux | High-performance |
| **Windows Terminal** | Windows | Works with WSL/SSH |
| **Foot** | Linux/Wayland | Lightweight |
| **Tabby** | Cross-platform | May need config for >1KB payloads |
| **Mintty** | Windows/Cygwin | Enable `AllowSetSelection` |
| **xterm** | Linux | Requires `allowWindowOps: true` |
| **Chrome OS Terminal** | ChromeOS | Built-in support |

### ❌ No OSC52 Support

These terminals **do NOT support OSC52** - clipboard requires X11 forwarding:

| Terminal | Reason | Workaround |
|----------|--------|------------|
| **GNOME Terminal** | VTE library limitation | Use X11 or switch terminal |
| **XFCE Terminal** | VTE library limitation | Use X11 or switch terminal |
| **Tilix** | VTE library limitation | Use X11 or switch terminal |
| **Terminator** | No support | Use X11 or switch terminal |
| **VS Code Terminal** | xterm.js limitation | Use X11 or external terminal |
| **PuTTY** | No support | Use KiTTY fork or X11 |
| **Konsole** | Partial (v24.08+) | Update to latest version |

## Testing Your Terminal

Run this command to test if your terminal supports OSC52:

```bash
printf "\033]52;c;$(printf "clipboard-test" | base64)\a"
```

Then press `Cmd+V` (macOS) or `Ctrl+V` (Linux/Windows). If you see `clipboard-test`, your terminal supports OSC52.

## Troubleshooting

### "Copy" doesn't work in my AI tool

1. **Check your terminal** - Is it in the supported list above?
2. **Test OSC52** - Run the test command above
3. **If OSC52 fails** - Your terminal doesn't support it

### Using an unsupported terminal?

**Option 1: Switch terminals** (Recommended)
- Install iTerm2, Warp, Kitty, or Alacritty

**Option 2: Enable X11 forwarding** (macOS)
```bash
# Install XQuartz
brew install --cask xquartz

# Start XQuartz and set DISPLAY
open -a XQuartz
export DISPLAY=:0

# Now run your AI tool
opencode
```

**Option 3: Use terminal's native copy**
- Select text with mouse
- Use `Cmd+C` / `Ctrl+Shift+C` to copy from terminal output
- This bypasses the container entirely

### Clipboard works in terminal but not in the AI tool

The AI tool (e.g., OpenCode, Aider) must also support OSC52. If the tool uses system clipboard libraries like `xclip` directly, it will fail without X11.

Check if the tool has OSC52 support in its settings or documentation.

## Technical Details

### OSC52 Protocol

OSC52 is an escape sequence that tells the terminal to copy text to clipboard:

```
\033]52;c;<base64-encoded-text>\007
```

- `\033]52;` - OSC 52 sequence start
- `c` - clipboard selection (could also be `p` for primary)
- `<base64>` - The text to copy, base64 encoded
- `\007` - Sequence terminator

### X11 Forwarding

When X11 is available, `ai-run` automatically:
1. Detects `$DISPLAY` environment variable
2. Mounts `/tmp/.X11-unix` socket into container
3. Forwards `~/.Xauthority` for authentication
4. Tools like `xclip` can then access host clipboard

### Container Detection

The `ai-run` script detects display configuration at runtime:

```bash
# Check if X11 available
if [[ -n "$DISPLAY" ]]; then
  # Mount X11 socket and auth
fi

# Check if Wayland available  
if [[ -n "$WAYLAND_DISPLAY" ]]; then
  # Mount Wayland runtime dir
fi
```

If neither is available, clipboard tools (`xclip`, `wl-copy`) won't work, but OSC52 still can if your terminal supports it.

## See Also

- [RESEARCH_CLIPBOARD.md](RESEARCH_CLIPBOARD.md) - Initial clipboard analysis
- [CLIPBOARD_ANALYSIS_REPORT.md](CLIPBOARD_ANALYSIS_REPORT.md) - Detailed implementation audit
- [DEBUG_OPENCODE_CLIPBOARD.md](DEBUG_OPENCODE_CLIPBOARD.md) - OpenCode-specific troubleshooting
