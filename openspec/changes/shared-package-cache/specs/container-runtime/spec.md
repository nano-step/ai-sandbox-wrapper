## MODIFIED Requirements

### Requirement: core-addons-availability
Standard addon tools (`uipro`, `specify`) MUST be available and executable by the non-root `agent` user within the AI sandbox container environment. Package manager caches SHALL use shared host-side cache directories instead of per-tool or ephemeral caches.

#### Scenario: run-uipro-in-container
- **WHEN** user executes `ai-run <tool> --shell`
- **AND** types `uipro --version` inside the container
- **THEN** command should execute successfully and show the version

#### Scenario: run-specify-in-container
- **WHEN** user executes `ai-run <tool> --shell`
- **AND** types `specify --help` inside the container
- **THEN** command should execute successfully and show help output

#### Scenario: npx packages use shared cache
- **WHEN** user executes `ai-run opencode`
- **AND** the agent runs `npx @playwright/mcp` inside the container
- **THEN** the downloaded package SHALL be stored in the shared npm cache at `~/.ai-sandbox/cache/npm/`
- **AND** a subsequent `ai-run claude` session running the same `npx` command SHALL use the cached package

## REMOVED Requirements

### Requirement: OpenCode anonymous volume cache isolation
The container runtime SHALL no longer create anonymous Docker volumes to isolate `.npm`, `.cache`, and `.opencode/node_modules` for OpenCode sessions.

**Reason**: Replaced by shared cache mounts that provide proper cache persistence while avoiding host/container conflicts through mount overlay precedence.
**Migration**: No user action needed. The shared cache mounts automatically replace the anonymous volume behavior.
