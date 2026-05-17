## Why

AI coding agents inside the sandbox need tmux for terminal multiplexing — running persistent background processes, managing multiple terminal sessions, and supporting tools like OpenCode that use tmux for interactive shell management. Without tmux, agents cannot use `interactive_bash` (tmux-based) tool calls, limiting their ability to run TUI apps, long-running processes, and multi-pane workflows.

## What Changes

- Add `tmux` to the `apt-get install` package list in `dockerfiles/base/Dockerfile`
- Add `tmux` to the `apt-get install` package list in `dockerfiles/sandbox/Dockerfile`

## Capabilities

### New Capabilities

- `tmux-support`: Install tmux in sandbox container images so AI agents can use terminal multiplexing for background processes, interactive TUI apps, and multi-session workflows.

### Modified Capabilities

- `base-image`: Adding tmux to the base system packages installed via apt-get.

## Impact

- **Dockerfiles**: `dockerfiles/base/Dockerfile` and `dockerfiles/sandbox/Dockerfile` — one package added to existing apt-get install line
- **Image size**: Minimal increase (~1-2 MB for tmux package)
- **Security**: No new attack surface — tmux is a standard terminal multiplexer with no network capabilities or privilege escalation risk
- **CI**: Images will need rebuild to include tmux
