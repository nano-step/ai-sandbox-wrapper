# web-command-detection Specification

## Purpose
Automatic detection and configuration of tool web server subcommands, enabling seamless port exposure and hostname configuration without manual user intervention.

## ADDED Requirements

### Requirement: OpenCode Web Command Detection
The container runtime SHALL automatically detect when the `opencode web` subcommand is invoked and configure port exposure accordingly.

#### Scenario: Basic web command detection
- **WHEN** user runs `ai-run opencode web`
- **THEN** the runtime SHALL detect the `web` subcommand
- **AND** the runtime SHALL automatically expose port 4096 (OpenCode default)
- **AND** the runtime SHALL display a message: `🌐 Web UI available at http://localhost:4096`

#### Scenario: Web command with custom port
- **WHEN** user runs `ai-run opencode web --port 8080`
- **THEN** the runtime SHALL parse the `--port 8080` argument from tool arguments
- **AND** the runtime SHALL automatically expose port 8080
- **AND** the runtime SHALL display a message: `🌐 Web UI available at http://localhost:8080`

#### Scenario: Web command with equals-style port
- **WHEN** user runs `ai-run opencode web --port=8080`
- **THEN** the runtime SHALL parse the `--port=8080` argument
- **AND** the runtime SHALL automatically expose port 8080

#### Scenario: Non-web command not detected
- **WHEN** user runs `ai-run opencode` (without `web` subcommand)
- **THEN** the runtime SHALL NOT auto-detect web mode
- **AND** the runtime SHALL NOT automatically expose any ports

### Requirement: Hostname Injection
The container runtime SHALL automatically inject `--hostname 0.0.0.0` when web command is detected, unless the user explicitly specifies a hostname.

#### Scenario: Automatic hostname injection
- **WHEN** user runs `ai-run opencode web`
- **THEN** the runtime SHALL inject `--hostname 0.0.0.0` into the tool arguments
- **AND** the web server SHALL be accessible from the host machine

#### Scenario: User-specified hostname preserved
- **WHEN** user runs `ai-run opencode web --hostname 127.0.0.1`
- **THEN** the runtime SHALL NOT inject `--hostname 0.0.0.0`
- **AND** the user-specified hostname SHALL be preserved

#### Scenario: Hostname with equals-style preserved
- **WHEN** user runs `ai-run opencode web --hostname=192.168.1.100`
- **THEN** the runtime SHALL NOT inject `--hostname 0.0.0.0`
- **AND** the user-specified hostname SHALL be preserved

### Requirement: Port Combination
The container runtime SHALL combine manually exposed ports with auto-detected ports without duplicates.

#### Scenario: Manual and auto-detected ports combined
- **WHEN** user runs `ai-run opencode --expose 3000,5000 web --port 4096`
- **THEN** the runtime SHALL expose ports 3000, 5000, AND 4096
- **AND** all three ports SHALL be accessible from the host

#### Scenario: Duplicate port handling
- **WHEN** user runs `ai-run opencode --expose 4096 web --port 4096`
- **THEN** the runtime SHALL expose port 4096 only once
- **AND** no duplicate port mapping error SHALL occur

#### Scenario: Auto-detected port with PORT_BIND
- **WHEN** user runs `ai-run opencode web --port 8080` with `PORT_BIND=all`
- **THEN** the auto-detected port 8080 SHALL be bound to `0.0.0.0`
- **AND** a security warning SHALL be displayed

### Requirement: Web Detection Feedback
The container runtime SHALL provide clear feedback when web command is detected and configured.

#### Scenario: Detection message in interactive mode
- **WHEN** user runs `ai-run opencode web` in interactive terminal
- **THEN** the runtime SHALL display: `🌐 Detected web command. Auto-exposing port <port>.`
- **AND** the runtime SHALL display the access URL after container starts

#### Scenario: Detection message in non-interactive mode
- **WHEN** user runs `ai-run opencode web` in non-interactive mode (e.g., script)
- **THEN** the runtime SHALL still display detection messages to stderr
- **AND** the container SHALL start normally

#### Scenario: Debug output includes web detection
- **WHEN** `AI_RUN_DEBUG=1` is set and user runs `ai-run opencode web --port 8080`
- **THEN** the debug output SHALL show the detected web command
- **AND** the debug output SHALL show the parsed port value
- **AND** the debug output SHALL show the injected hostname
