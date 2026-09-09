# Design: OSC 52 Clipboard Support

## Context

The previous `enable-clipboard-support` change implemented X11/Wayland forwarding. This covers Linux desktop users but leaves macOS and remote SSH users behind. OSC 52 is an ANSI escape sequence that allows an application to send clipboard data to the terminal emulator.

## Decisions

-   **Implement `osc52-copy` as a shell script.**
    -   Rationale: Lightweight, no dependencies (just `base64` and `printf`), works everywhere.
    -   Script: `printf "\033]52;c;$(base64 | tr -d '\n')\a"`

-   **Shim `pbcopy` to `osc52-copy`.**
    -   Rationale: macOS users expect `pbcopy`. Since `pbcopy` doesn't exist in Linux containers, we can claim this namespace.
    -   This allows `cat file | pbcopy` to work "magically" for macOS users inside the container.

-   **Do NOT replace `xclip`/`wl-copy` by default.**
    -   Rationale: If X11/Wayland *is* available, those are faster/better (support selections, etc.). OSC 52 is a fallback or explicit choice.

## Open Questions

-   **Paste Support?** OSC 52 paste is security-restricted in most terminals (browsers/terminals don't let apps *read* clipboard without prompt). We will focus on **Copy** only for now.

## Risks

-   **Terminal Support**: Some older terminals (Terminal.app on macOS) don't support OSC 52. However, it fails silently (garbage text is hidden) or just doesn't copy. This is an acceptable fallback.
