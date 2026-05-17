## ADDED Requirements

### Requirement: tmux available in container images
The base and sandbox container images SHALL include tmux as a pre-installed system package, available to the `agent` user at runtime.

#### Scenario: tmux is available after container start
- **WHEN** a container is started from the base or sandbox image
- **THEN** the `tmux` binary SHALL be available in the system PATH
- **AND** the `agent` user SHALL be able to execute `tmux` without elevated privileges

#### Scenario: Agent creates a tmux session
- **WHEN** the `agent` user runs `tmux new-session -d -s mysession`
- **THEN** a new detached tmux session named `mysession` SHALL be created
- **AND** the agent SHALL be able to send commands to it via `tmux send-keys`

#### Scenario: tmux works in non-interactive mode
- **WHEN** an AI agent tool (e.g., `interactive_bash`) invokes tmux subcommands programmatically
- **THEN** tmux SHALL execute the subcommands without requiring an interactive terminal
