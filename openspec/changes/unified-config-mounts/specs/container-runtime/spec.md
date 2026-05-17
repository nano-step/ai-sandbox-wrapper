## MODIFIED Requirements

### Requirement: core-addons-availability
Standard addon tools (`uipro`, `specify`) and all installed AI tools MUST have their config directories bind-mounted from the host into the container. The home directory SHALL be a single shared location (`~/.ai-sandbox/home/`) instead of per-tool directories.

#### Scenario: run-uipro-in-container
- **WHEN** user executes `ai-run <tool> --shell`
- **AND** types `uipro --version` inside the container
- **THEN** command should execute successfully and show the version

#### Scenario: run-specify-in-container
- **WHEN** user executes `ai-run <tool> --shell`
- **AND** types `specify --help` inside the container
- **THEN** command should execute successfully and show help output

#### Scenario: all-tool-configs-available
- **WHEN** user executes `ai-run` in any mode (shell, tool-specific)
- **THEN** config directories for ALL installed tools SHALL be bind-mounted from the host
- **AND** any tool run inside the container SHALL read/write its real host config

## REMOVED Requirements

### Requirement: Per-tool home directory isolation
The container runtime SHALL no longer maintain separate home directories per tool (`~/.ai-sandbox/tools/{tool}/home/`). All sessions use a single shared home.

**Reason**: The unified tool image puts all tools in one container. Per-tool home isolation fragments state (shell history, dotfiles, tool-generated files) and causes config to be saved to the wrong location when switching tools mid-session.
**Migration**: Existing per-tool home directories are automatically merged into `~/.ai-sandbox/home/` on first run. Old directories are preserved until the user runs `clean`.
