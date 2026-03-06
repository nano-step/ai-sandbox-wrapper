## Why

Claude Code's Agent Teams feature enables coordinated multi-agent workflows where a lead agent delegates tasks to teammates via shared task lists, inter-agent messaging, and tmux split-pane display. Combined with CCS (Claude Code Switch), users can switch between AI providers (Claude, Gemini, DeepSeek, 300+ via OpenRouter) and manage multiple Claude accounts. The sandbox currently supports basic Claude Code execution but lacks the container-level dependencies (tmux, CCS, Node.js) and configuration mounts needed for these advanced workflows. Adding this support positions the sandbox as a first-class environment for multi-agent AI development.

## What Changes

- Install CCS (`@kaitranntt/ccs`) npm package in the Claude Code Docker image for multi-provider model switching
- Install tmux in the Claude Code Docker image (required for Agent Teams split-pane mode)
- Add Node.js/npm to the Claude Code image (CCS dependency; currently the image uses native binary only)
- Mount CCS configuration directory (`~/.config/ccs` or CCS's profile storage path) for persistence across container runs
- Mount Claude Code's teams/tasks directories (`~/.claude/teams/`, `~/.claude/tasks/`) for Agent Teams state persistence
- Pass `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` environment variable to enable Agent Teams
- Pass additional provider API keys (OPENROUTER_API_KEY, GOOGLE_API_KEY, etc.) for CCS multi-provider support
- Update documentation with CCS usage, Agent Teams setup, and known limitations

## Capabilities

### New Capabilities
- `claude-agent-teams`: Support for Claude Code Agent Teams inside the sandbox container, including tmux dependency, teams/tasks state persistence, and environment configuration
- `claude-ccs-integration`: CCS (Claude Code Switch) installation and configuration for multi-provider model switching and multi-account management inside the sandbox

### Modified Capabilities
- `container-runtime`: Additional environment variables and volume mounts for Claude Code Agent Teams and CCS
- `base-image`: Potential Node.js/npm addition if CCS requires it at the base level (or Claude-image-only change)

## Impact

### Files Changed
- `lib/install-claude.sh` — Dockerfile generation: add tmux, Node.js/npm, CCS installation
- `dockerfiles/claude/Dockerfile` — Generated Dockerfile with new dependencies
- `bin/ai-run` — Claude case: add CCS config mount, teams/tasks dir mounts, new env vars
- `~/.ai-sandbox/env` — Document new optional keys (OPENROUTER_API_KEY, GOOGLE_API_KEY, etc.)
- `TOOLS.md` — Claude section: document CCS and Agent Teams usage
- `setup.sh` — Potentially add CCS/Agent Teams opt-in during setup

### Dependencies Added
- tmux (apt package, ~2MB) — inside Claude container
- Node.js + npm (already in ai-base via Bun, but CCS may need npm specifically)
- `@kaitranntt/ccs` (npm package)

### Risks & Open Questions
1. **tmux-in-Docker**: Agent Teams uses tmux split-panes. Running tmux inside a Docker container requires proper TTY allocation and may have limitations with nested tmux (host tmux → container tmux). Needs investigation.
2. **CCS OAuth flows**: CCS supports OAuth for Gemini/Copilot (browser-based auth). This may not work inside a headless Docker container. API-key-based providers should work fine.
3. **Image size increase**: Adding Node.js + tmux + CCS will increase the `ai-claude` image size. Need to measure impact.
4. **CCS config storage**: Need to verify where CCS stores profiles/credentials to ensure correct volume mount path.
5. **Agent Teams state**: Teams config lives at `~/.claude/teams/` and tasks at `~/.claude/tasks/`. The current mount of `~/.claude` should cover this, but needs verification.
6. **Security**: CCS stores API keys for multiple providers. These persist in `~/.config/ccs/` on the host — consistent with existing sandbox security model (user-managed secrets).
