## Why

Users currently experience friction when trying to copy/paste text or paste images into AI tools running in the sandbox. The containers are effectively air-gapped from the host clipboard, causing failures in tools like `vim` or AI REPLs. We need to bridge this gap to improve usability, especially for terminal users (Warp, etc.).

## What Changes

- Update `dockerfiles/base/Dockerfile` to include essential clipboard utilities: `xclip`, `xsel`, and `wl-clipboard`.
- Modify `bin/ai-run` to automatically detect host display servers (X11 or Wayland).
- Configure `bin/ai-run` to securely forward necessary environment variables (`DISPLAY`, `WAYLAND_DISPLAY`) and mount sockets (`/tmp/.X11-unix`, `/run/user/X/bus`) when appropriate.

## Capabilities

### New Capabilities
- `clipboard-integration`: Bi-directional clipboard sharing between host and container.

### Modified Capabilities
- (none)

## Impact

- `bin/ai-run`: Significant logic addition for display detection and forwarding.
- `dockerfiles/base`: Minor increase in image size; requires rebuild.
- Security: Need to ensure socket mounting is done securely (e.g., read-only where possible, or user-scoped).
