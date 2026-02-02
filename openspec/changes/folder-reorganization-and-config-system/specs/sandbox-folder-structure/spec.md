# sandbox-folder-structure Specification

## ADDED Requirements

### Requirement: Tool-Centric Directory Layout
The AI Sandbox SHALL organize all tool-specific data under `~/.ai-sandbox/tools/<tool>/` where `<tool>` is the name of the AI tool (e.g., amp, opencode, claude).

#### Scenario: Tool directory structure
- **WHEN** a user runs `ai-run <tool>` for any supported tool
- **THEN** the system SHALL create `~/.ai-sandbox/tools/<tool>/home/` if it does not exist
- **AND** the system SHALL create `~/.ai-sandbox/tools/<tool>/cache/` if it does not exist

#### Scenario: Home directory mounting
- **WHEN** a container is started for a tool
- **THEN** `~/.ai-sandbox/tools/<tool>/home/` SHALL be mounted as `/home/agent` in the container
- **AND** the mount SHALL be read-write with `delegated` consistency

#### Scenario: Cache directory mounting
- **WHEN** a container is started for a tool
- **THEN** `~/.ai-sandbox/tools/<tool>/cache/` SHALL be mounted as `/home/agent/.cache` in the container

### Requirement: Shared Git Directory
The AI Sandbox SHALL maintain shared Git/SSH configuration in `~/.ai-sandbox/shared/git/` for use by all tools.

#### Scenario: SSH configuration location
- **WHEN** Git access is enabled for a workspace
- **THEN** cached SSH keys SHALL be stored in `~/.ai-sandbox/shared/git/ssh/`
- **AND** the SSH directory SHALL be mounted as `/home/agent/.ssh:ro` in the container

#### Scenario: Per-workspace key selections
- **WHEN** a user selects specific SSH keys for a workspace
- **THEN** the selection SHALL be stored in `~/.ai-sandbox/shared/git/keys/<workspace-hash>`
- **AND** the hash SHALL be the first 8 characters of the MD5 hash of the workspace path

### Requirement: Native Tool Configuration Compatibility
The AI Sandbox SHALL preserve each tool's native configuration structure so tools work seamlessly without modification.

#### Scenario: Tool config auto-copy on first run
- **WHEN** `ai-run <tool>` is executed for the first time for a tool
- **AND** the host has native config at `~/.config/<tool>/` or `~/.<tool>/`
- **AND** no config exists in `~/.ai-sandbox/tools/<tool>/home/`
- **THEN** the system SHALL copy the host config to the sandbox home directory
- **AND** the system SHALL display "✓ Copied <source> → <dest>"

#### Scenario: Standard XDG config path
- **WHEN** a tool runs inside the container and expects config at `~/.config/<tool>/`
- **THEN** it SHALL find its config at `/home/agent/.config/<tool>/`
- **AND** the config SHALL be the user's host config that was copied into the sandbox

#### Scenario: Legacy dotfile config path
- **WHEN** a tool uses legacy config at `~/.<tool>/` (e.g., `~/.claude/`, `~/.aider/`)
- **THEN** it SHALL find its config at `/home/agent/.<tool>/`
- **AND** the config SHALL be the user's host config that was copied into the sandbox

#### Scenario: Tool data persistence
- **WHEN** a tool modifies its config or stores data during a session
- **THEN** changes SHALL persist in `~/.ai-sandbox/tools/<tool>/home/`
- **AND** changes SHALL be available in subsequent sessions

#### Scenario: Supported tool config locations
- **WHEN** copying tool configs on first run
- **THEN** the system SHALL support these tool-specific paths:
  - amp: `~/.config/amp/`, `~/.local/share/amp/`
  - opencode: `~/.config/opencode/`
  - claude: `~/.claude/`
  - aider: `~/.config/aider/`, `~/.aider/`
  - gemini: `~/.config/gemini/`
  - kilo: `~/.config/kilo/`
  - codex: `~/.config/codex/`
  - qwen: `~/.config/qwen/`
  - droid: `~/.config/droid/`
  - qoder: `~/.config/qoder/`
  - auggie: `~/.config/auggie/`
  - codebuddy: `~/.config/codebuddy/`
  - jules: `~/.config/jules/`
  - shai: `~/.config/shai/`

### Requirement: Automatic Migration from Legacy Paths
The AI Sandbox SHALL automatically migrate data from legacy paths on first run after upgrade.

#### Scenario: Home directory migration
- **WHEN** `ai-run` is executed and `~/.ai-sandbox/home/<tool>/` exists
- **AND** `~/.ai-sandbox/tools/<tool>/home/` does not exist
- **THEN** the system SHALL move `~/.ai-sandbox/home/<tool>/` to `~/.ai-sandbox/tools/<tool>/home/`
- **AND** the system SHALL display a migration success message

#### Scenario: Cache directory migration
- **WHEN** `ai-run` is executed and `~/.ai-sandbox/cache/<tool>/` exists
- **AND** `~/.ai-sandbox/tools/<tool>/cache/` does not exist
- **THEN** the system SHALL move `~/.ai-sandbox/cache/<tool>/` to `~/.ai-sandbox/tools/<tool>/cache/`

#### Scenario: Git cache migration
- **WHEN** `ai-run` is executed and `~/.ai-sandbox/cache/git/` exists
- **THEN** the system SHALL move `~/.ai-sandbox/cache/git/` to `~/.ai-sandbox/shared/git/`

#### Scenario: Git keys migration
- **WHEN** `ai-run` is executed and `~/.ai-sandbox/git-keys/` exists
- **THEN** the system SHALL move `~/.ai-sandbox/git-keys/` to `~/.ai-sandbox/shared/git/keys/`

#### Scenario: Migration marker
- **WHEN** migration completes successfully
- **THEN** the system SHALL create `~/.ai-sandbox/.migrated-v2` with a timestamp
- **AND** subsequent runs SHALL skip migration if the marker exists
