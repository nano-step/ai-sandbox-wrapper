# Troubleshooting Report: OpenCode Clipboard Failure

## Root Cause Analysis

1.  **Environment is Valid**: The fact that you can "copy normal from the beginning" (using terminal commands like `xclip`) confirms that the X11 forwarding and socket mounts are working correctly. The container *can* talk to your host clipboard.
2.  **App-Specific Failure**: The failure is isolated to `opencode`. Since it reports "Copied", it believes it succeeded.
3.  **Library Conflict (`xsel` vs `xclip`)**: Most Go applications (including those built with Bubble Tea) use the `atotto/clipboard` library. This library checks for `xsel` *before* `xclip`.
    *   `xsel` behavior can be flaky in some forwarded X11 environments compared to `xclip`.
    *   By installing *both* `xsel` and `xclip` in the base image, we likely inadvertently forced `opencode` to use `xsel`, which might be failing silently or writing to the wrong selection (Primary vs Clipboard).

## Proposed Fix

**Remove `xsel` and force `xclip`.**

`xclip` is generally more robust for X11 forwarding scenarios. By removing `xsel` from the image, we force Go applications to fall back to `xclip`, which we know works in your environment.

## Action Plan

I will modify the base image installation to **remove** `xsel` and only install `xclip` and `wl-clipboard`.

### Verification Steps (After Fix)

1.  Rebuild the image: `bash lib/install-base.sh`
2.  Run `ai-run opencode`
3.  Select text and copy.
4.  Paste on host.
