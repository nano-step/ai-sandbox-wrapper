## 1. Base Image Updates

- [x] 1.1 Update `dockerfiles/base/Dockerfile` to install `xclip`, `xsel`, and `wl-clipboard` in the existing package install block
- [x] 1.2 Rebuild the base image using the project build script or manual build instructions

## 2. Display Detection and Flag Generation

- [x] 2.1 Add `detect_display_config` in `bin/ai-run` to detect `DISPLAY` and `WAYLAND_DISPLAY` on the host
- [x] 2.2 Implement X11 flag generation (env vars, `/tmp/.X11-unix` mount, `XAUTHORITY` forwarding)
- [x] 2.3 Implement Wayland flag generation (`WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR`, socket mount)

## 3. Runner Integration

- [x] 3.1 Integrate generated display flags into the `docker run` command construction in `bin/ai-run`
- [x] 3.2 Add a debug log path when no display server is detected and continue without clipboard support

## 4. Verification

- [x] 4.1 Run a container and verify host-to-container and container-to-host clipboard for text
