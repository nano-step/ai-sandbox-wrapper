## Context

The AI sandbox wrapper provides Docker-based isolation for AI coding agents. Claude Code is currently supported as a native binary installation (via `curl -fsSL https://claude.ai/install.sh | bash`) with basic configuration mounting (`~/.claude`). The image uses the `ai-base` base image which includes Bun runtime and npm.

Claude Code v2.1.32+ introduced two experimental features:

1. **Agent Teams**: Multi-agent workflows where a lead agent delegates tasks to teammates via shared task lists and inter-agent messaging. Supports two display modes:
   - `in-process`: All teammates in one terminal (default)
   - `tmux`: Split-pane display using tmux (requires tmux binary)

2. **CCS (Claude Code Switch)**: Multi-provider model switching and multi-account management. Supports:
   - 300+ AI providers via OpenRouter, Ollama, custom endpoints
   - OAuth providers (Gemini, Copilot, Codex) requiring browser login
   - API-key providers (OpenRouter, Ollama, custom) for headless use
   - Multi-account Claude management

Agent Teams requires:
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` environment variable
- tmux binary (for `tmux` mode only)
- State persistence at `~/.claude/teams/` and `~/.claude/tasks/`

CCS requires:
- Node.js >= 18 or Bun >= 1.0 (for npm installation)
- Configuration storage at `~/.ccs/` (config.yaml, OAuth tokens in `cliproxy/auth/`, instances, shared commands)

## Goals / Non-Goals

**Goals:**
- Install tmux in the Claude-specific image for Agent Teams split-pane mode support
- Install CCS via npm in the Claude-specific image for multi-provider switching
- Mount CCS configuration directory (`~/.ccs`) for persistence across container runs
- Document Agent Teams setup, CCS usage, and environment variable requirements
- Document OAuth provider limitations in headless Docker containers
- Default to `in-process` teammate mode for maximum compatibility

**Non-Goals:**
- Modifying the base image (tmux and CCS are Claude-specific)
- Auto-configuring Agent Teams (user opts in via environment variable)
- Supporting OAuth providers in headless mode (document limitation only)
- Adding a `--teams` flag to ai-run (Claude handles this internally)
- Pre-configuring CCS profiles (user responsibility)
- Installing tmux in base image (only Claude needs it)

## Decisions

### Decision 1: tmux Installation Location

**Choice**: Install tmux in the Claude-specific image (`ai-claude`), not the base image.

**Rationale**:
- Only Claude Code needs tmux for Agent Teams split-pane mode
- Other 14 tools in the sandbox don't require tmux
- Keeps base image lean and focused on common dependencies
- Follows existing pattern of tool-specific dependencies in tool images

**Alternatives Considered**:
- Install in base image → Rejected: Unnecessary bloat for all other tools
- Skip tmux entirely → Rejected: Users would lose split-pane visualization option

### Decision 2: Agent Teams Teammate Mode Default

**Choice**: Default to `in-process` mode (all teammates in one terminal), let users opt into `tmux` mode.

**Rationale**:
- `in-process` mode works everywhere without tmux dependency
- `tmux` mode requires both tmux binary AND either a tmux session or iTerm2
- Containers may be accessed from various terminals (SSH, VS Code, etc.)
- `in-process` is the safest default for container environments
- Users can explicitly set `CLAUDE_CODE_TEAMMATE_MODE=tmux` if desired

**Alternatives Considered**:
- Default to `tmux` mode → Rejected: Would fail if user's terminal doesn't support it
- Default to `auto` mode → Acceptable alternative, but explicit `in-process` is more predictable

### Decision 3: CCS Installation in Claude Image

**Choice**: Install CCS via `npm install -g @kaitranntt/ccs` in the Claude Dockerfile. Use Node.js (already available via base image's npm).

**Rationale**:
- CCS supports both Node.js >= 18 and Bun >= 1.0
- The base image already has npm available
- Global install makes `ccs` binary available system-wide
- Follows existing pattern for npm-based tools in the sandbox

**Alternatives Considered**:
- Use Bun instead of npm → Acceptable but npm is more standard for global installs in Docker
- Install CCS at runtime → Rejected: Slower startup, version inconsistency

### Decision 4: CCS Config Persistence

**Choice**: Mount `~/.ccs` from host to container via `mount_tool_config "$HOME/.ccs" ".ccs"` in the Claude case of ai-run.

**Rationale**:
- CCS stores all configuration in `~/.ccs/` directory:
  - `config.yaml`: Main configuration
  - `cliproxy/auth/`: OAuth tokens
  - `instances/`: Provider instances
  - `shared/`: Shared commands
- Single mount covers all CCS state
- CCS_DIR environment variable can override but default `~/.ccs` is fine
- Follows existing pattern of mounting tool config directories

**Alternatives Considered**:
- Mount individual subdirectories → Rejected: Fragile, breaks if CCS adds new subdirs
- Use environment variable override → Unnecessary complexity

### Decision 5: Agent Teams State Persistence

**Choice**: No additional mounts needed - existing `mount_tool_config "$HOME/.claude" ".claude"` already covers `~/.claude/teams/` and `~/.claude/tasks/`.

**Rationale**:
- Agent Teams stores team configs at `~/.claude/teams/{team-name}/config.json`
- Agent Teams stores task lists at `~/.claude/tasks/{team-name}/`
- The existing `.claude` mount is a parent directory mount that includes these subdirectories
- No changes needed to ai-run for Agent Teams state persistence

**Alternatives Considered**:
- Add explicit mounts for `~/.claude/teams/` and `~/.claude/tasks/` → Rejected: Redundant with existing parent mount

### Decision 6: Environment Variable Strategy

**Choice**: Pass `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` via the env file (`~/.ai-sandbox/env`), not hardcoded in Dockerfile.

**Rationale**:
- Agent Teams is experimental and may change or break
- Users should explicitly opt-in by adding the env var to their env file
- Follows existing pattern where API keys and feature flags are user-managed
- Allows users to disable the feature without rebuilding the image

**Alternatives Considered**:
- Hardcode in Dockerfile → Rejected: Forces feature on all users, can't disable without rebuild
- Add `--teams` flag to ai-run → Rejected: Unnecessary complexity, env var is sufficient

### Decision 7: OAuth Provider Limitation Documentation

**Choice**: Document that OAuth-based CCS providers (Gemini, Copilot, Codex) require browser login on first use and may not work in headless Docker. Recommend API-key providers (OpenRouter, Ollama, custom endpoints) for container use.

**Rationale**:
- Docker containers are headless by default
- OAuth device flows (like Copilot) might work via URL copy-paste
- Browser-redirect OAuth won't work without X11 forwarding or similar
- This is a known limitation of headless environments, not a bug to fix
- API-key providers work perfectly in containers

**Alternatives Considered**:
- Add X11 forwarding support → Rejected: Massive complexity, security risk
- Implement OAuth device flow workarounds → Rejected: Out of scope, CCS handles this

## Risks / Trade-offs

### Risk 1: Image Size Increase
**Risk**: tmux (~2MB) + CCS npm package (~50MB with dependencies) increases Claude image size.
**Mitigation**: Both are in Claude-specific image only, not base image. Users who don't use Claude aren't affected.

### Risk 2: CCS Version Drift
**Risk**: CCS is actively developed (v7.45.0+). Using `@latest` tag may introduce breaking changes.
**Mitigation**: Same pattern as other npm tools in the sandbox. Users can rebuild to get updates or pin versions if needed.

### Risk 3: Agent Teams Experimental Status
**Risk**: Feature may change or break in future Claude Code releases.
**Mitigation**: Environment variable opt-in means users explicitly choose to use experimental features. Clear documentation of experimental status.

### Risk 4: Nested tmux Complexity
**Risk**: If user runs ai-run from within a host tmux session, Agent Teams' tmux mode creates nested tmux, which can be confusing.
**Mitigation**: `in-process` default avoids this. Document tmux prefix key rebinding if users want nested tmux.

### Risk 5: Claude Code Version Requirement
**Risk**: Agent Teams requires Claude Code v2.1.32+. Older versions in cache may not work.
**Mitigation**: The install script uses `curl -fsSL https://claude.ai/install.sh | bash` which always gets latest version.

### Risk 6: OAuth Provider Limitations
**Risk**: Users may expect OAuth providers (Gemini, Copilot) to work seamlessly in containers.
**Mitigation**: Clear documentation in TOOLS.md about OAuth limitations and recommended API-key providers.

## Implementation Approach

### File Changes

1. **`lib/install-claude.sh`**
   - Add tmux installation (as root, before USER agent)
   - Add CCS installation via npm (as root for global install)
   - Update feature list in output message

2. **`bin/ai-run`**
   - Claude case (line 590-592): Add `mount_tool_config "$HOME/.ccs" ".ccs"`
   - No changes needed for Agent Teams state (existing `.claude` mount covers it)

3. **`TOOLS.md`**
   - Claude section: Document Agent Teams setup
   - Document CCS installation and usage
   - Document required environment variables
   - Document OAuth provider limitations
   - Provide example CCS configuration

4. **`setup.sh`** (optional)
   - Add mention of Agent Teams and CCS during Claude tool selection
   - No interactive prompts needed (features are opt-in via env vars)

### Dockerfile Generation Pattern

```bash
# In lib/install-claude.sh, modify Dockerfile generation:

cat <<'EOF' > "dockerfiles/$TOOL/Dockerfile"
FROM ai-base:latest

USER root
# Install tmux for Agent Teams split-pane mode
RUN apt-get update && apt-get install -y tmux && rm -rf /var/lib/apt/lists/*

# Install CCS for multi-provider switching
RUN npm install -g @kaitranntt/ccs

# Install Claude Code using official native installer
RUN curl -fsSL https://claude.ai/install.sh | bash && \
    mkdir -p /usr/local/share && \
    mv /home/agent/.local/share/claude /usr/local/share/claude && \
    ln -sf /usr/local/share/claude/versions/$(ls /usr/local/share/claude/versions | head -1) /usr/local/bin/claude

USER agent
ENTRYPOINT ["claude"]
EOF
```

### ai-run Mount Addition

```bash
# In bin/ai-run, Claude case (around line 590):
"claude")
  mount_tool_config "$HOME/.claude" ".claude"
  mount_tool_config "$HOME/.ccs" ".ccs"  # Add this line
  ;;
```

### Documentation Example (TOOLS.md)

```markdown
## Claude Code

### Agent Teams (Experimental)

Enable multi-agent workflows:

1. Add to `~/.ai-sandbox/env`:
   ```
   CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
   ```

2. Optionally set teammate display mode:
   ```
   CLAUDE_CODE_TEAMMATE_MODE=in-process  # Default: all in one terminal
   CLAUDE_CODE_TEAMMATE_MODE=tmux        # Split-pane display (requires tmux)
   ```

3. Run Claude Code normally:
   ```bash
   ai-run claude
   ```

### CCS (Claude Code Switch)

Switch between AI providers and manage multiple accounts:

1. Install CCS (already included in Claude image)

2. Configure providers:
   ```bash
   ai-run claude --shell
   ccs config add openrouter --api-key YOUR_KEY
   ccs config add ollama --base-url http://localhost:11434
   ```

3. Add provider API keys to `~/.ai-sandbox/env`:
   ```
   OPENROUTER_API_KEY=sk-or-...
   GOOGLE_API_KEY=...
   ```

4. Switch providers:
   ```bash
   ccs use openrouter
   ccs use claude  # Back to Claude
   ```

**OAuth Providers**: Gemini, Copilot, and Codex require browser login. These may not work in headless Docker. Use API-key providers (OpenRouter, Ollama, custom endpoints) for container use.
```

### User Environment Setup

Users add to `~/.ai-sandbox/env`:

```bash
# Agent Teams (opt-in)
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
CLAUDE_CODE_TEAMMATE_MODE=in-process  # or tmux

# CCS Multi-Provider Support
OPENROUTER_API_KEY=sk-or-...
GOOGLE_API_KEY=...
# Other provider keys as needed
```
