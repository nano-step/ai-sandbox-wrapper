## ADDED Requirements

### Requirement: Mount all installed tools' configs
The system SHALL mount config directories for ALL tools listed in `config.json` `tools.installed` into every container session, regardless of which tool is specified on the command line.

#### Scenario: Shell mode gets all configs
- **WHEN** user runs `ai-run` without a tool argument (shell mode)
- **THEN** config directories for all installed tools SHALL be bind-mounted into the container
- **AND** running any installed tool inside the container SHALL use the real host config

#### Scenario: Tool mode gets all configs
- **WHEN** user runs `ai-run opencode`
- **AND** `tools.installed` contains `["opencode", "claude", "gemini"]`
- **THEN** config directories for opencode, claude, AND gemini SHALL all be bind-mounted
- **AND** running `claude` inside the container SHALL use `~/.claude` from the host

#### Scenario: Tool run inside container saves config to host
- **WHEN** user runs `ai-run opencode`
- **AND** runs `amp` inside the container which writes to `/home/agent/.config/amp/`
- **THEN** the config SHALL be persisted to `~/.config/amp/` on the host
- **AND** a subsequent `ai-run amp` session SHALL see the same config

#### Scenario: Fallback when tools.installed is empty
- **WHEN** `config.json` does not contain `tools.installed` or the array is empty
- **THEN** the system SHALL mount config directories for ALL known tools in the registry
- **AND** empty host directories SHALL be created as needed (harmless no-op)

### Requirement: Shared home directory
The system SHALL use a single shared home directory (`~/.ai-sandbox/home/`) mounted as `/home/agent` for all container sessions, replacing per-tool home directories.

#### Scenario: Same home across tools
- **WHEN** user runs `ai-run opencode` and creates a file at `/home/agent/notes.txt`
- **AND** later runs `ai-run claude`
- **THEN** `/home/agent/notes.txt` SHALL be present in the claude session

#### Scenario: Shell history shared
- **WHEN** user runs `ai-run opencode` and executes commands
- **AND** later runs `ai-run` in shell mode
- **THEN** the shell history from the opencode session SHALL be available

### Requirement: Migration from per-tool homes
The system SHALL automatically migrate existing per-tool home directories (`~/.ai-sandbox/tools/*/home/`) into the shared home (`~/.ai-sandbox/home/`) on first run after update.

#### Scenario: First run triggers migration
- **WHEN** user updates ai-sandbox-wrapper and runs `ai-run` for the first time
- **AND** `~/.ai-sandbox/tools/opencode/home/` and `~/.ai-sandbox/tools/claude/home/` exist
- **THEN** the system SHALL merge contents into `~/.ai-sandbox/home/`
- **AND** existing files in the shared home SHALL NOT be overwritten (first-wins)
- **AND** the system SHALL display migration progress

#### Scenario: Migration runs only once
- **WHEN** migration has already completed (marker file exists)
- **THEN** the system SHALL skip migration on subsequent runs

#### Scenario: Old directories preserved
- **WHEN** migration completes
- **THEN** the original per-tool home directories SHALL NOT be deleted
- **AND** the system SHALL suggest running `clean` to remove them
