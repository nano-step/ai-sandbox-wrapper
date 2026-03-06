## Context

The sandbox containers currently lack tmux, which AI agents need for terminal multiplexing. Tools like OpenCode use tmux for `interactive_bash` tool calls to manage TUI apps and background processes. Both `dockerfiles/base/Dockerfile` and `dockerfiles/sandbox/Dockerfile` have an initial `apt-get install` line (line 9 in both) where system packages are listed.

## Goals / Non-Goals

**Goals:**
- Install tmux in both base and sandbox Docker images
- Follow existing package installation pattern (single apt-get line)

**Non-Goals:**
- Custom tmux configuration (agents configure their own)
- tmux plugin management
- Changes to entrypoints or runtime behavior

## Decisions

### Add tmux to existing apt-get install line
**Decision**: Append `tmux` to the existing `apt-get install` command on line 9 of both Dockerfiles, rather than adding a separate `RUN apt-get` layer.

**Rationale**: Follows the existing pattern — all base system packages are installed in a single `apt-get` call to minimize Docker layers and image size. Adding a separate RUN would create an unnecessary layer.

**Alternative considered**: Separate `RUN apt-get install tmux` — rejected because it adds an extra layer and diverges from the established pattern.

## Risks / Trade-offs

- **[Minimal image size increase]** → tmux adds ~1-2 MB. Acceptable given the utility it provides.
- **[Two Dockerfiles to update]** → base and sandbox Dockerfiles are maintained separately (not DRY). Both must be updated. This is the existing pattern for this project.
