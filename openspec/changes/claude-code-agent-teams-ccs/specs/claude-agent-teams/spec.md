# claude-agent-teams Specification

## Purpose
Claude Code Agent Teams support inside the Docker sandbox container, enabling multi-agent workflows with shared task lists and split-pane display.

## ADDED Requirements

### Requirement: tmux Installation
The Claude Code Docker image SHALL include tmux for Agent Teams split-pane display mode.

#### Scenario: tmux available in container
- **WHEN** user runs `ai-run claude --shell`
- **AND** types `tmux -V` inside the container
- **THEN** tmux SHALL be installed and display its version
- **AND** tmux SHALL be executable by the non-root `agent` user

#### Scenario: tmux not required for in-process mode
- **WHEN** user runs Claude Code with Agent Teams in `in-process` mode
- **THEN** Agent Teams SHALL function without tmux being started
- **AND** all teammates SHALL display in the same terminal

### Requirement: Agent Teams Environment Variable
The sandbox SHALL support enabling Agent Teams via environment variable.

#### Scenario: Agent Teams enabled via env file
- **WHEN** user adds `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` to `~/.ai-sandbox/env`
- **AND** runs `ai-run claude`
- **THEN** the environment variable SHALL be passed to the container
- **AND** Claude Code SHALL recognize Agent Teams as enabled

#### Scenario: Agent Teams disabled by default
- **WHEN** `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is not set in `~/.ai-sandbox/env`
- **THEN** Agent Teams SHALL not be enabled
- **AND** Claude Code SHALL operate in standard single-agent mode

### Requirement: Agent Teams State Persistence
Agent Teams state SHALL persist across container restarts via the existing `~/.claude` mount.

#### Scenario: Team configuration persistence
- **WHEN** user creates an agent team in Claude Code
- **AND** the container is stopped and restarted
- **THEN** team configurations at `~/.claude/teams/{team-name}/config.json` SHALL be preserved
- **AND** the team SHALL be available in the new container session

#### Scenario: Task list persistence
- **WHEN** an agent team creates shared tasks
- **AND** the container is stopped and restarted
- **THEN** task lists at `~/.claude/tasks/{team-name}/` SHALL be preserved
- **AND** task state (pending, in_progress, completed) SHALL be maintained

### Requirement: Teammate Display Mode Configuration
The sandbox SHALL support configuring the teammate display mode via environment variable.

#### Scenario: In-process mode (default)
- **WHEN** `CLAUDE_CODE_TEAMMATE_MODE` is not set or set to `in-process`
- **THEN** all teammates SHALL display in the same terminal
- **AND** user SHALL use Shift+Up/Down to switch between teammates

#### Scenario: tmux split-pane mode
- **WHEN** `CLAUDE_CODE_TEAMMATE_MODE=tmux` is set in `~/.ai-sandbox/env`
- **AND** the container has tmux installed
- **THEN** each teammate SHALL get a dedicated tmux pane
- **AND** the user SHALL see all teammates simultaneously

### Requirement: Claude Code Version Compatibility
The Claude Code installation SHALL meet the minimum version requirement for Agent Teams.

#### Scenario: Version check
- **WHEN** Claude Code is installed in the container
- **THEN** the version SHALL be 2.1.32 or higher
- **AND** running `claude --version` SHALL confirm compatibility
