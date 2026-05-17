## MODIFIED Requirements

### Requirement: Runtime Port Exposure
The container runtime (`bin/ai-run`) SHALL support exposing container ports to the host via the `--expose` flag (primary) or `PORT` environment variable (deprecated). Port exposure SHALL work with the unified `ai-sandbox:latest` image.

#### Scenario: Single port exposure
- **WHEN** `--expose 3000` flag is provided when running ai-run
- **THEN** the container SHALL map port 3000 from the `ai-sandbox:latest` container to host
- **AND** the port SHALL be bound to `127.0.0.1` by default (localhost only)

#### Scenario: Multiple port exposure
- **WHEN** `--expose 3000,5555,5556,5557` flag is provided when running ai-run
- **THEN** the container SHALL map all specified ports from the `ai-sandbox:latest` container to host
- **AND** each port SHALL be bound according to the `PORT_BIND` setting

#### Scenario: Invalid port handling
- **WHEN** an invalid port number is specified (e.g., `--expose 99999` or `--expose abc`)
- **THEN** the invalid port SHALL be skipped with a warning message
- **AND** valid ports in the same list SHALL still be mapped

## ADDED Requirements

### Requirement: Unified image resolution
The container runtime SHALL resolve to `ai-sandbox:latest` instead of per-tool `ai-{tool}:latest` images.

#### Scenario: Local image resolution without tool argument
- **WHEN** user runs `ai-run` without a tool argument
- **THEN** the runtime SHALL use `ai-sandbox:latest`
- **AND** the container SHALL start in interactive shell mode

#### Scenario: Local image resolution with tool argument
- **WHEN** user runs `ai-run claude`
- **THEN** the runtime SHALL use `ai-sandbox:latest` (NOT `ai-claude:latest`)
- **AND** the container SHALL run with `--entrypoint claude`

#### Scenario: Registry image resolution
- **WHEN** `AI_IMAGE_SOURCE=registry` is set
- **THEN** the runtime SHALL use `registry.gitlab.com/kokorolee/ai-sandbox-wrapper/ai-sandbox:latest`

### Requirement: Shell-first default
When no tool argument is provided, `ai-run` SHALL default to shell mode instead of requiring a tool name.

#### Scenario: No tool argument in interactive mode
- **WHEN** user runs `ai-run` with a TTY attached
- **THEN** the container SHALL start with an interactive bash shell
- **AND** a welcome message SHALL be displayed listing available tools

#### Scenario: No tool argument in non-interactive mode
- **WHEN** user runs `ai-run` without a TTY (e.g., piped or CI)
- **THEN** the runtime SHALL display an error: "No tool specified and no TTY available. Use: ai-run <tool>"
- **AND** the container SHALL NOT be started

### Requirement: Entrypoint override for direct tool execution
When a tool name is provided, `ai-run` SHALL override the container's default CMD to run that tool directly.

#### Scenario: Direct tool execution
- **WHEN** user runs `ai-run opencode`
- **THEN** the container SHALL run with `--entrypoint opencode`
- **AND** any additional arguments SHALL be passed to the tool

#### Scenario: Tool with arguments
- **WHEN** user runs `ai-run opencode web --port 4096`
- **THEN** the container SHALL run `opencode web --port 4096`

#### Scenario: Shell flag overrides tool execution
- **WHEN** user runs `ai-run claude --shell`
- **THEN** the container SHALL start in shell mode (NOT run claude directly)
- **AND** claude SHALL be available as a command inside the shell
