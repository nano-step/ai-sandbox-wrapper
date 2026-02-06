# Clipboard & Image Access Analysis

The current AI Sandbox architecture is designed for **strict isolation**, which intentionally breaks the link between the container and your host's clipboard/display server.

## 1. Why "Copy Text" Fails

The containers are "headless" and lack both the **connection** and the **tools** to talk to your host's clipboard.

| Component | Status | Missing Configuration |
|-----------|--------|-----------------------|
| **Connection** | ❌ Disconnected | `bin/ai-run` does not forward X11 (`/tmp/.X11-unix`) or Wayland sockets. |
| **Tools** | ❌ Missing | `dockerfiles/base/Dockerfile` does not install `xclip`, `xsel`, or `wl-clipboard`. |
| **Access** | ❌ Blocked | No `DISPLAY` or `WAYLAND_DISPLAY` environment variables are passed to the container. |

**Result:** When you try to copy text (e.g., from `vim` or an AI tool inside the container), the command fails silently or errors because it can't find a clipboard provider.

## 2. Why "Paste Image" Fails

Pasting images is more complex and fails for two reasons depending on how you try to paste:

### Scenario A: Pasting Binary Image Data (Ctrl+V)
- **Mechanism:** Requires the terminal emulator to send image data to the running application via specific protocols (like OSC 52 or Kitty protocol).
- **Failure:** Even if your terminal supports this, the application inside the container (e.g., `aider`) acts as if it's running in a minimal environment. Without clipboard access, it can't "request" the image data from your system clipboard.

### Scenario B: Pasting "File Path"
- **Mechanism:** Some terminals paste the *file path* when you drop an image.
- **Failure:** The container is **isolated**. If you paste a path like `/Users/you/Downloads/image.png`, the container **cannot see that file** because it only has access to your whitelisted workspace (e.g., `/workspace`).
- **Fix:** You must move the image *into* your project folder (workspace) first, then paste the relative path.

## Technical Summary

The `bin/ai-run` script (lines 1211-1229) creates a secure boundary:
```bash
docker run ...
  # Missing: -e DISPLAY=$DISPLAY
  # Missing: -v /tmp/.X11-unix:/tmp/.X11-unix
  # Missing: --device /dev/dri
  ...
```

And `dockerfiles/base/Dockerfile` (line 7) installs base utils (`git`, `curl`) but omits clipboard utilities:
```dockerfile
RUN apt-get install -y ... git curl ssh ... # No xclip/xsel here
```

## Workaround Recommendations

1.  **For Images:** Move the image into your project directory *on your host machine* first. Then, in the AI tool, reference it by its local path (e.g., `/user-login-screen.png`).
2.  **For Text:** Use your terminal's native copy feature (e.g., `Cmd+C` on macOS) by selecting text with your mouse. This bypasses the container and copies directly from the terminal window output.
