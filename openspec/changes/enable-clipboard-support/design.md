## Context

Clipboard integration is currently unavailable in sandboxed AI containers because the runtime wrapper does not forward display sockets or environment variables, and the base image lacks clipboard utilities. Users in terminal environments (Warp, etc.) cannot reliably copy/paste text or images in editors or REPLs. The change spans the runtime wrapper (`bin/ai-run`) and the base image (`dockerfiles/base/Dockerfile`) and must balance usability with host security exposure.

## Goals / Non-Goals

**Goals:**
- Enable bidirectional clipboard sharing when the host provides X11 or Wayland display services.
- Ensure containers include standard clipboard tools for text/image copy/paste (`xclip`, `xsel`, `wl-clipboard`).
- Automatically detect display availability and enable forwarding by default.

**Non-Goals:**
- Introducing a new CLI flag for opt-out or opt-in behavior (future work).
- Supporting remote display protocols beyond X11/Wayland (e.g., RDP, VNC).
- Building a separate security sandbox around clipboard access.

## Decisions

- **Install clipboard utilities in the base image.**
  - Rationale: These tools are de-facto standards used by terminals and editors; keeping them in the base image ensures consistent availability across tools.
  - Alternative: Install tools per-container/tool image. Rejected because it increases duplication and misses tools derived from the base image.

- **Auto-detect X11/Wayland and enable forwarding by default.**
  - Rationale: Users expect copy/paste to work out of the box; the wrapper already handles other host integrations and should make a best-effort configuration.
  - Alternative: Manual flags or config-only activation. Rejected for usability (extra steps) and because the sandbox is already trusted for local tools.

- **X11 forwarding via socket mount plus XAuthority forwarding.**
  - Rationale: X11 requires the `/tmp/.X11-unix` socket and appropriate authentication. Mounting host `~/.Xauthority` read-only and setting `XAUTHORITY` inside the container enables tools to connect without custom auth flow.
  - Alternative: Disable XAuthority forwarding and rely on `xhost` configuration. Rejected due to user burden and weaker defaults.

- **Wayland forwarding via `WAYLAND_DISPLAY` and runtime dir mount.**
  - Rationale: Wayland sockets live under the host's XDG runtime directory, so mounting that directory (or the specific socket) to `/run/user/1001` and setting `XDG_RUNTIME_DIR` allows tools like `wl-copy`/`wl-paste` to function.
  - Alternative: Force XWayland usage only. Rejected because it fails on Wayland-only hosts.

- **Graceful fallback when no display is detected.**
  - Rationale: Avoid breaking container runs. Log a debug message and proceed without clipboard integration.

## Risks / Trade-offs

- [Host security exposure via X11 socket] → Document the risk, keep mounts minimal, and ensure XAuthority is read-only to reduce leakage.
- [Wayland runtime dir exposure] → Prefer mounting only the socket when possible; otherwise mount the runtime directory read-only where compatible.
- [Platform variance in runtime paths/UIDs] → Use detected `XDG_RUNTIME_DIR` on host when available and map to container `/run/user/1001` to match the agent UID.
- [Image size increase] → Accept small size increase; keep package installation consolidated with existing apt installs.

## Migration Plan

- Update `dockerfiles/base/Dockerfile` to install clipboard packages in the existing package install block.
- Extend `bin/ai-run` to detect `DISPLAY`/`WAYLAND_DISPLAY` and append the appropriate env/mount flags.
- Rebuild base images and verify clipboard commands (`xclip`, `xsel`, `wl-copy`, `wl-paste`) run in a container.
- Rollback: remove the added packages and runtime flags if regressions or security concerns arise.

## Open Questions

- Should the Wayland mount be limited to the socket path only, or is the full runtime dir needed on all distros?
- Should an opt-out flag (`--no-clipboard`) be added soon after to mitigate risk for untrusted tools?
