# Add OSC 52 Clipboard Support

## Why

The current clipboard implementation relies exclusively on X11 (`DISPLAY`) or Wayland (`WAYLAND_DISPLAY`) forwarding. This fails for:
1.  **macOS users** (unless running XQuartz).
2.  **SSH users** (unless forwarding X11).
3.  **Headless environments**.

Users in these environments cannot copy text from the container to their host clipboard, which is a critical usability issue for a coding sandbox.

## What Changes

-   **Base Image (`dockerfiles/base/Dockerfile`)**:
    -   Add a lightweight `osc52-copy` script (using `base64` and ANSI escape sequences).
    -   Alias/Symlink `pbcopy` to `osc52-copy` (providing a familiar interface for macOS users).
    -   (Optional) Configure `vim`/`neovim` to use this provider if present.

## Capabilities

### New Capabilities
-   **OSC 52 Fallback**: Clipboard copying works even without a display server, provided the terminal emulator supports OSC 52 (supported by iTerm2, Warp, Alacritty, Windows Terminal, VSCode, etc.).

## Impact

-   **Reliability**: Copy works in 99% of modern terminals, regardless of OS.
-   **Security**: No socket mounting required. Pure text stream (safe).
