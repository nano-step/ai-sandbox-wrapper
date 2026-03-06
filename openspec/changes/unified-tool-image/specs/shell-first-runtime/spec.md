## ADDED Requirements

### Requirement: Shell-first default mode
When `ai-run` is invoked without a tool argument, it SHALL open an interactive shell inside the unified sandbox container with all installed tools available as commands.

#### Scenario: Running ai-run without arguments
- **WHEN** user runs `ai-run` (no tool argument)
- **THEN** the container SHALL start with an interactive bash shell
- **AND** all installed AI tools SHALL be available as commands (e.g., `claude`, `opencode`, `gemini`)
- **AND** a welcome message SHALL list the available tools

#### Scenario: Running ai-run with a tool argument
- **WHEN** user runs `ai-run claude`
- **THEN** the container SHALL start with `claude` as the entrypoint (direct execution)
- **AND** the behavior SHALL be equivalent to the old `ai-run claude` (tool runs directly, container exits when tool exits)

#### Scenario: Running ai-run with tool and arguments
- **WHEN** user runs `ai-run opencode web --port 4096`
- **THEN** the container SHALL run `opencode web --port 4096` directly
- **AND** all existing flags (`--shell`, `--network`, `--expose`, etc.) SHALL continue to work

### Requirement: Tool availability validation
`ai-run` SHALL validate that a requested tool is installed in the unified image before launching.

#### Scenario: Requesting an installed tool
- **WHEN** user runs `ai-run claude` and "claude" is in `config.json` `tools.installed`
- **THEN** the container SHALL launch normally with claude

#### Scenario: Requesting a tool not installed
- **WHEN** user runs `ai-run gemini` and "gemini" is NOT in `config.json` `tools.installed`
- **THEN** `ai-run` SHALL display: "Tool 'gemini' is not installed. Run setup.sh to add it."
- **AND** the container SHALL NOT be started

#### Scenario: Config file missing or unreadable
- **WHEN** `config.json` does not exist or `tools.installed` is missing
- **THEN** `ai-run` SHALL skip validation and attempt to run the tool
- **AND** a warning SHALL be displayed: "Cannot verify tool availability (config missing)"

### Requirement: Unified image resolution
`ai-run` SHALL resolve to `ai-sandbox:latest` instead of per-tool images.

#### Scenario: Local image resolution
- **WHEN** `AI_IMAGE_SOURCE` is not set or set to "local"
- **THEN** `ai-run` SHALL use `ai-sandbox:latest` regardless of which tool is specified

#### Scenario: Registry image resolution
- **WHEN** `AI_IMAGE_SOURCE=registry` is set
- **THEN** `ai-run` SHALL use `registry.gitlab.com/kokorolee/ai-sandbox-wrapper/ai-sandbox:latest`

### Requirement: Shell welcome message
When entering shell mode, the container SHALL display a welcome message listing available tools.

#### Scenario: Welcome message content
- **WHEN** user enters shell mode (either `ai-run` or `ai-run --shell`)
- **THEN** the welcome message SHALL list all installed AI tools with their names
- **AND** the welcome message SHALL list available enhancement tools (uipro, specify, openspec, rtk)
- **AND** the welcome message SHALL show basic usage hints

### Requirement: Tool-specific config mounts preserved
`ai-run` SHALL continue to mount tool-specific configuration directories based on the tool argument, even with the unified image.

#### Scenario: Running claude with config mounts
- **WHEN** user runs `ai-run claude`
- **THEN** `~/.claude` and `~/.ccs` SHALL be mounted into the container
- **AND** the mount behavior SHALL be identical to the previous per-tool image approach

#### Scenario: Running shell mode with no specific tool
- **WHEN** user runs `ai-run` (shell mode, no tool)
- **THEN** no tool-specific config mounts SHALL be applied
- **AND** only the base home directory mount SHALL be used

#### Scenario: Running shell mode and switching tools inside
- **WHEN** user runs `ai-run`, enters shell, then runs `claude` inside the container
- **THEN** claude SHALL work but tool-specific host configs (e.g., `~/.claude`) will NOT be mounted
- **AND** this is expected behavior — tool configs are only mounted when specified via `ai-run {tool}`
