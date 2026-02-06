# Clipboard Integration Analysis Report
## AI Sandbox Wrapper - Comprehensive Configuration Audit

**Date:** February 4, 2026  
**Scope:** Analysis of clipboard support across `setup.sh`, `bin/ai-run`, `dockerfiles/opencode/Dockerfile`, and related `lib/` install scripts.

---

## Executive Summary

The AI Sandbox Wrapper has **recently implemented clipboard support** (in progress via OpenSpec change `enable-clipboard-support`). The current state is:

| Component | Status | Details |
|-----------|--------|---------|
| **Clipboard Tools** | ✅ Installed | `xclip` and `wl-clipboard` in base image (lines 6-7 of `lib/install-base.sh`) |
| **X11 Forwarding** | ✅ Implemented | Auto-detection in `bin/ai-run` (lines 1073-1098) |
| **Wayland Forwarding** | ✅ Implemented | Auto-detection in `bin/ai-run` (lines 1100-1112) |
| **TERM Configuration** | ✅ Passed Through | `TERM` and `COLORTERM` env vars forwarded (lines 1282-1283 of `bin/ai-run`) |
| **Terminal Size** | ✅ Configured | `COLUMNS` and `LINES` detected and passed (line 1246 of `bin/ai-run`) |
| **Graceful Fallback** | ✅ Implemented | Debug logging when display unavailable (lines 1115-1117) |

---

## 1. Clipboard Tools Installation

### Location
- **File:** `/lib/install-base.sh` (part of `dockerfiles/base/Dockerfile`)
- **Line:** ~6-7 (within RUN apt-get install block)

### Installed Tools
```bash
xclip           # X11 clipboard provider (primary for Go apps like opencode)
wl-clipboard    # Wayland clipboard provider (wl-copy/wl-paste)
```

### Configuration Details

**From `dockerfiles/base/Dockerfile` line 7:**
```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ssh ca-certificates jq python3 python3-pip python3-venv \
    python3-dev python3-setuptools build-essential libopenblas-dev pipx \
    unzip \
    xclip \              # ← Clipboard tool (X11)
    wl-clipboard \       # ← Clipboard tool (Wayland)
    && curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin sh \
    && rm -rf /var/lib/apt/lists/* \
    && pipx ensurepath
```

### Design Notes

- **Why both?** The system auto-detects the display server (X11 vs Wayland) at runtime and uses the appropriate tool.
- **`xsel` was removed:** According to `DEBUG_OPENCODE_CLIPBOARD.md`, early versions installed both `xsel` and `xclip`. The Go library `atotto/clipboard` prefers `xsel`, which is flaky in forwarded X11. Removing `xsel` forces apps to use the more robust `xclip`.
- **Lightweight:** Combined size impact is minimal; both are small utilities.

---

## 2. Display & Clipboard Detection (`bin/ai-run`)

### Function: `detect_display_config()`

**Location:** Lines 1073-1120 in `bin/ai-run`

### Implementation Details

#### 2.1 X11 Detection (Lines 1078-1098)

```bash
if [[ -n "$DISPLAY" ]]; then
  has_display=true
  detected_flags="$detected_flags -e DISPLAY=$DISPLAY"

  # Mount X11 socket (common on Linux/macOS with XQuartz)
  if [[ -d "/tmp/.X11-unix" ]]; then
    detected_flags="$detected_flags -v /tmp/.X11-unix:/tmp/.X11-unix:rw"
  fi

  # Handle XAuthority for authentication
  if [[ -f "$HOME/.Xauthority" ]]; then
    detected_flags="$detected_flags -e XAUTHORITY=/tmp/.Xauthority"
    detected_flags="$detected_flags -v $HOME/.Xauthority:/tmp/.Xauthority:ro"
  fi

  echo "$detected_flags"
  return
fi
```

**What it does:**
1. Checks if `$DISPLAY` is set (indicates X11 server available)
2. Passes `DISPLAY` env var to container
3. Mounts `/tmp/.X11-unix` socket (RW) from host into container
4. Mounts `$HOME/.Xauthority` read-only to `/tmp/.Xauthority` in container for X11 authentication
5. Sets `XAUTHORITY` env var inside container to `/tmp/.Xauthority`

**Security Notes:**
- X11 socket mount is RW (necessary for clipboard operations)
- XAuthority is mounted read-only to minimize risk
- Placed outside `/home/agent` mount to avoid conflicts (line 1091)

**Rationale (from design.md):**
> "X11 requires the `/tmp/.X11-unix` socket and appropriate authentication. Mounting host `~/.Xauthority` read-only and setting `XAUTHORITY` inside the container enables tools to connect without custom auth flow."

#### 2.2 Wayland Detection (Lines 1100-1112)

```bash
if [[ -n "$WAYLAND_DISPLAY" ]]; then
  has_display=true
  detected_flags="$detected_flags -e WAYLAND_DISPLAY=$WAYLAND_DISPLAY"

  # Handle XDG_RUNTIME_DIR (needed for Wayland sockets)
  if [[ -n "$XDG_RUNTIME_DIR" ]]; then
    local container_runtime_dir="/run/user/1001"
    detected_flags="$detected_flags -e XDG_RUNTIME_DIR=$container_runtime_dir"
    detected_flags="$detected_flags -v $XDG_RUNTIME_DIR:$container_runtime_dir:rw"
  fi
fi
```

**What it does:**
1. Checks if `$WAYLAND_DISPLAY` is set (indicates Wayland server available)
2. Passes `WAYLAND_DISPLAY` env var to container
3. Mounts host's `$XDG_RUNTIME_DIR` to container's `/run/user/1001` (agent UID)
4. Sets `XDG_RUNTIME_DIR` env var inside container to `/run/user/1001`

**Why `/run/user/1001`?**
- Container runs as user `agent` with UID 1001 (set in `dockerfiles/base/Dockerfile` line 32)
- Wayland sockets are typically at `$XDG_RUNTIME_DIR/wayland-X`
- Container must mount to a matching UID directory so Wayland tools can find sockets

#### 2.3 Fallback Behavior (Lines 1115-1117)

```bash
if [[ "$has_display" == "false" && "${AI_RUN_DEBUG:-}" == "1" ]]; then
  echo "🔧 Debug: No display server detected (DISPLAY/WAYLAND_DISPLAY unset). Clipboard integration disabled." >&2
fi
```

**Behavior:**
- If neither X11 nor Wayland detected, **container starts successfully without clipboard**
- Debug message only shown if `AI_RUN_DEBUG=1` is set (avoid unnecessary output)
- Prevents container from failing if user runs in non-graphical environment

---

## 3. Terminal Configuration

### TERM & Color Support

**Location:** Lines 1282-1283 in `bin/ai-run`

```bash
docker run ... \
  -e TERM="$TERM" \
  -e COLORTERM="$COLORTERM" \
  $TERMINAL_SIZE \
  "$IMAGE" "${DOCKER_COMMAND[@]}"
```

**What it does:**
- **`TERM`** - Passes host terminal type (e.g., `xterm-256color`, `screen.xterm-256color`) to container
  - Allows container apps to render colors and formatting correctly
  - Compatible with clipboard: X11 apps can use `TERM` to determine if clipboard operations are safe
  
- **`COLORTERM`** - Indicates true color support (usually `truecolor` or `24bit`)
  - Tells container apps they can use 24-bit RGB colors

- **`COLUMNS` & `LINES`** - Dynamic terminal size (lines 1244-1246)
  ```bash
  TERM_COLS=$(tput cols 2>/dev/null || echo "120")
  TERM_LINES=$(tput lines 2>/dev/null || echo "40")
  TERMINAL_SIZE="-e COLUMNS=$TERM_COLS -e LINES=$TERM_LINES"
  ```

### Clipboard Relevance

The `TERM` variable affects:
1. **OSC 52 Support Detection** - Apps check `TERM` to determine if OSC 52 clipboard protocol is safe
2. **Terminal Emulator Detection** - Some apps optimize clipboard behavior based on terminal type
3. **Color & Formatting** - TUI apps like opencode need correct TERM to render properly

---

## 4. Display & Socket Mounting

### Mounts Generated by `detect_display_config()`

| Mount Point | Type | Purpose | Mode |
|-------------|------|---------|------|
| `/tmp/.X11-unix` | X11 socket | Connect to host X11 server | RW |
| `$HOME/.Xauthority` → `/tmp/.Xauthority` | X11 auth file | Authenticate X11 connection | RO |
| `$XDG_RUNTIME_DIR` → `/run/user/1001` | Wayland sockets | Connect to host Wayland server | RW |

### Bind Mount Strategy

**From `bin/ai-run` lines 1350-354:**
```bash
# Build volume mounts for all whitelisted workspaces
VOLUME_MOUNTS=""
while IFS= read -r ws; do
  VOLUME_MOUNTS="$VOLUME_MOUNTS -v $ws:$ws:delegated"
done < "$WORKSPACES_FILE"
```

**Note:** Workspace mounts use `:delegated` flag for performance (macOS Docker Desktop optimization).

**X11/Wayland mounts use:**
- `:rw` for socket operations (clipboard operations require read-write)
- `:ro` only for XAuthority file (minimize attack surface)

---

## 5. Search Results Summary

### Grep Findings

#### Clipboard Tools
```bash
grep -r "xclip\|wl-clipboard" /lib/
  → Found in: install-base.sh (lines 6-7)
```

#### TERM Configuration
```bash
grep -n "TERM\|COLORTERM" /bin/ai-run
  → Lines 1282-1283: -e TERM="$TERM" -e COLORTERM="$COLORTERM"
  → Lines 1244-1246: Terminal size via TERM_COLS/TERM_LINES
```

#### Display Configuration
```bash
grep -n "DISPLAY\|XAUTHORITY\|WAYLAND" /bin/ai-run
  → Lines 1078-1098: X11 detection and mounts
  → Lines 1100-1112: Wayland detection and mounts
  → Lines 1115-1117: Fallback behavior
```

#### OSC 52 & Protocols
```bash
grep -r "OSC 52" /
  → Found in: RESEARCH_CLIPBOARD.md (mentioned as limitation)
  → Not currently implemented (terminal emulator passthrough only)
```

---

## 6. Current Architecture Overview

### Display Stack

```
┌──────────────────────────────────────────────────────┐
│  HOST SYSTEM (macOS/Linux)                           │
│  ┌──────────────────────────────────────────────┐    │
│  │ Display Server (X11 or Wayland)              │    │
│  │ Clipboard: /tmp/.X11-unix or $XDG_RUNTIME_DIR
│  └──────────────────────────────────────────────┘    │
│  ┌──────────────────────────────────────────────┐    │
│  │ Host Files                                   │    │
│  │ ~/.Xauthority (if X11)                       │    │
│  │ $XDG_RUNTIME_DIR (if Wayland)                │    │
│  └──────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────┘
           ↓ Detected & mounted by ai-run
┌──────────────────────────────────────────────────────┐
│  DOCKER CONTAINER                                    │
│  ┌──────────────────────────────────────────────┐    │
│  │ Environment Variables:                       │    │
│  │ DISPLAY=$DISPLAY (X11)                       │    │
│  │ WAYLAND_DISPLAY=$WAYLAND_DISPLAY (Wayland)  │    │
│  │ XAUTHORITY=/tmp/.Xauthority (X11)            │    │
│  │ XDG_RUNTIME_DIR=/run/user/1001 (Wayland)    │    │
│  │ TERM=$TERM, COLORTERM=$COLORTERM             │    │
│  └──────────────────────────────────────────────┘    │
│  ┌──────────────────────────────────────────────┐    │
│  │ Mounted Sockets & Files:                     │    │
│  │ /tmp/.X11-unix:RW (X11 socket)               │    │
│  │ /tmp/.Xauthority:RO (X11 auth)               │    │
│  │ /run/user/1001:RW (Wayland socket dir)       │    │
│  └──────────────────────────────────────────────┘    │
│  ┌──────────────────────────────────────────────┐    │
│  │ Installed Tools:                             │    │
│  │ xclip (X11 clipboard)                        │    │
│  │ wl-clipboard (Wayland: wl-copy/wl-paste)     │    │
│  └──────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────┘
           ↓ AI tool uses xclip/wl-copy
┌──────────────────────────────────────────────────────┐
│  APPLICATIONS (opencode, aider, vim, etc.)           │
│  Can copy/paste via standard clipboard tools         │
└──────────────────────────────────────────────────────┘
```

---

## 7. Known Limitations & Workarounds

### OSC 52 Protocol (Terminal Passthrough)

**Status:** Not implemented  
**File:** `/RESEARCH_CLIPBOARD.md` (mentioned as limitation)

**What is it?**
- OSC 52 is a terminal escape sequence that allows applications to interact with the terminal's clipboard
- Works even when X11/Wayland are unavailable
- Terminal emulator (e.g., iTerm2, WezTerm) handles clipboard operations

**Why not implemented?**
- Requires terminal emulator to support it (user's terminal, not the container)
- Container apps would need to detect OSC 52 support and use it
- Current approach (X11/Wayland forwarding) is more direct and robust

**Workaround:** If you have a terminal supporting OSC 52, clipboard *may* work through terminal passthrough without explicit forwarding (browser/app dependent).

### Image Pasting

**Status:** Limited support

**Scenario 1: Binary image data (Ctrl+V)**
- Requires OSC 52 or Kitty protocol support
- Container must request image from terminal
- Currently not well-supported

**Scenario 2: File path pasting**
- Container can only access whitelisted workspaces
- If you paste `/Users/you/Downloads/image.png`, the container **cannot access it**
- **Workaround:** Move image to your project directory first, then paste the local path

---

## 8. Security Considerations

### Risk Analysis

| Component | Risk Level | Mitigation |
|-----------|------------|-----------|
| X11 socket (RW) | Medium | Socket access allows clipboard interception, but only from container (already somewhat trusted) |
| Wayland socket (RW) | Medium | Similar to X11; limited to session services |
| XAuthority (RO) | Low | Read-only mount minimizes exposure; only for authentication |
| Clipboard tools | Low | Standard Linux utilities; no special privileges |

### Best Practices

1. **Clipboard is opt-in via display forwarding** - Only enabled if `$DISPLAY` or `$WAYLAND_DISPLAY` set
2. **Minimal socket exposure** - Only necessary sockets forwarded, not entire runtime
3. **XAuthority is read-only** - Prevents container from modifying authentication
4. **Still sandboxed from filesystem** - Container cannot access host files beyond whitelisted workspaces

### Future Hardening

From `design.md` open questions:
> "Should an opt-out flag (`--no-clipboard`) be added soon after to mitigate risk for untrusted tools?"

This flag could allow users to disable clipboard access for specific tools.

---

## 9. Platform-Specific Behavior

### macOS (with XQuartz)

```
$DISPLAY = /private/tmp/com.apple.launchd.XXXXX/org.xquartz:0
$XDG_RUNTIME_DIR = (usually not set)
```

**Behavior:**
- X11 detection triggers
- `/tmp/.X11-unix` mounted for clipboard
- `~/.Xauthority` forwarded for authentication
- Works with `xclip` (installed in base image)

### Linux (X11)

```
$DISPLAY = :0 or :1
$XDG_RUNTIME_DIR = /run/user/1000
```

**Behavior:**
- X11 detection triggers if `$DISPLAY` set
- `/tmp/.X11-unix` mounted
- `~/.Xauthority` forwarded
- Works with `xclip`

### Linux (Wayland)

```
$DISPLAY = (unset)
$WAYLAND_DISPLAY = wayland-0
$XDG_RUNTIME_DIR = /run/user/1000
```

**Behavior:**
- Wayland detection triggers
- `$XDG_RUNTIME_DIR` → `/run/user/1001` mounted
- Works with `wl-copy`/`wl-paste`

### Headless / CI Environments

```
$DISPLAY = (unset)
$WAYLAND_DISPLAY = (unset)
```

**Behavior:**
- No display server detected
- Debug message logged (if `AI_RUN_DEBUG=1`)
- Container starts normally without clipboard
- No failures or errors

---

## 10. Implementation Checklist

Based on OpenSpec change `enable-clipboard-support`:

- [x] **1.1** Update `dockerfiles/base/Dockerfile` to install `xclip` and `wl-clipboard`
- [x] **2.1** Add X11 detection and forwarding in `bin/ai-run` (lines 1073-1098)
- [x] **2.2** Add Wayland detection and forwarding in `bin/ai-run` (lines 1100-1112)
- [x] **3.1** Pass `TERM` and `COLORTERM` to container (lines 1282-1283)
- [x] **3.2** Add debug logging for missing display server (lines 1115-1117)
- [x] **4.1** Terminal size detection (`COLUMNS`/`LINES`) (lines 1244-1246)

---

## 11. Code Locations Reference

### Key Files & Lines

| Feature | File | Lines | Status |
|---------|------|-------|--------|
| Clipboard tools | `lib/install-base.sh` | ~6-7 | ✅ Installed |
| X11 forwarding | `bin/ai-run` | 1078-1098 | ✅ Implemented |
| Wayland forwarding | `bin/ai-run` | 1100-1112 | ✅ Implemented |
| TERM passthrough | `bin/ai-run` | 1282-1283 | ✅ Implemented |
| Terminal size | `bin/ai-run` | 1244-1246 | ✅ Implemented |
| Fallback behavior | `bin/ai-run` | 1115-1117 | ✅ Implemented |
| Display detection | `bin/ai-run` | 1073-1120 | ✅ Implemented |

### Configuration Files

- `~/.ai-sandbox/env` - API keys (no clipboard config needed)
- `~/.ai-sandbox/config.json` - Network config (no clipboard config)
- No clipboard-specific config file needed (auto-detect via display server)

---

## 12. Recommendations

### For Users

1. **Clipboard works by default** - X11/Wayland detection is automatic
2. **If clipboard fails:**
   - Check if your terminal has X11/Wayland display server running
   - Run `echo $DISPLAY` (X11) or `echo $WAYLAND_DISPLAY` (Wayland)
   - If both unset, clipboard cannot work (headless environment)
3. **For images:**
   - Move images to your project directory first
   - Paste relative paths instead of absolute paths
   - Container cannot access files outside whitelisted workspaces

### For Developers

1. **Testing clipboard:**
   ```bash
   AI_RUN_DEBUG=1 ai-run opencode
   # Check debug output for clipboard configuration
   ```

2. **Disabling clipboard (future):**
   - Consider adding `--no-clipboard` flag for untrusted tools
   - Already mentioned in design.md open questions

3. **Extending support:**
   - OSC 52 support could be added for terminal-native clipboard
   - Requires terminal emulator support and app-level changes

---

## Conclusion

The AI Sandbox Wrapper has **comprehensive clipboard support** implemented:

✅ **Bi-directional text clipboard** via X11/Wayland forwarding  
✅ **Automatic platform detection** (X11, Wayland, or headless)  
✅ **Terminal type and size passthrough** for proper rendering  
✅ **Secure by default** with minimal socket exposure  
✅ **Graceful fallback** when display unavailable  
✅ **Standard tools installed** (xclip, wl-clipboard)  

The implementation balances **usability** (auto-detection, standard tools) with **security** (read-only auth, minimal mounts, graceful failures).

---

## Appendix: Related Documentation

- `DEBUG_OPENCODE_CLIPBOARD.md` - Troubleshooting for opencode-specific issues
- `RESEARCH_CLIPBOARD.md` - Analysis of clipboard mechanisms and limitations
- `openspec/changes/enable-clipboard-support/design.md` - Design decisions and architecture
- `openspec/changes/enable-clipboard-support/proposal.md` - Original proposal
