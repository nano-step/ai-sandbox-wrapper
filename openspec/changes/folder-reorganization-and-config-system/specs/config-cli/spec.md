# config-cli Specification

## ADDED Requirements

### Requirement: Interactive Configuration Update
The CLI SHALL provide an interactive TUI for managing sandbox configuration.

#### Scenario: Launch interactive mode
- **WHEN** user runs `npx @kokorolx/ai-sandbox-wrapper update`
- **THEN** the system SHALL display an interactive menu
- **AND** the menu SHALL use arrow keys for navigation
- **AND** the menu SHALL use space to toggle selections
- **AND** the menu SHALL use enter to confirm

#### Scenario: Interactive workspace management
- **WHEN** user selects "Manage Workspaces" in the interactive menu
- **THEN** the system SHALL display current whitelisted workspaces
- **AND** the system SHALL provide options to add or remove workspaces

#### Scenario: Interactive git access management
- **WHEN** user selects "Manage Git Access" in the interactive menu
- **THEN** the system SHALL display workspaces with git access enabled
- **AND** the system SHALL provide options to enable/disable git for workspaces

#### Scenario: Interactive network management
- **WHEN** user selects "Manage Networks" in the interactive menu
- **THEN** the system SHALL display available Docker networks
- **AND** the system SHALL allow selecting networks for global or per-workspace access

### Requirement: CLI Workspace Commands
The CLI SHALL provide scripting-friendly commands for workspace management.

#### Scenario: Add workspace
- **WHEN** user runs `npx @kokorolx/ai-sandbox-wrapper workspace add <path>`
- **THEN** the absolute path SHALL be added to `config.json.workspaces`
- **AND** the system SHALL confirm with "Added workspace: <path>"
- **AND** the command SHALL exit with code 0

#### Scenario: Add workspace with tilde expansion
- **WHEN** user runs `npx @kokorolx/ai-sandbox-wrapper workspace add ~/projects`
- **THEN** the path SHALL be expanded to the full home directory path
- **AND** the expanded path SHALL be stored in config

#### Scenario: Add duplicate workspace
- **WHEN** user runs `npx @kokorolx/ai-sandbox-wrapper workspace add <path>` for an existing workspace
- **THEN** the system SHALL display "Workspace already exists: <path>"
- **AND** the command SHALL exit with code 0 (not an error)

#### Scenario: Remove workspace
- **WHEN** user runs `npx @kokorolx/ai-sandbox-wrapper workspace remove <path>`
- **THEN** the path SHALL be removed from `config.json.workspaces`
- **AND** the system SHALL confirm with "Removed workspace: <path>"

#### Scenario: Remove non-existent workspace
- **WHEN** user runs `npx @kokorolx/ai-sandbox-wrapper workspace remove <path>` for a non-existent workspace
- **THEN** the system SHALL display "Workspace not found: <path>"
- **AND** the command SHALL exit with code 1

#### Scenario: List workspaces
- **WHEN** user runs `npx @kokorolx/ai-sandbox-wrapper workspace list`
- **THEN** the system SHALL display all configured workspaces, one per line

### Requirement: CLI Git Access Commands
The CLI SHALL provide scripting-friendly commands for Git access management.

#### Scenario: Enable git globally
- **WHEN** user runs `npx @kokorolx/ai-sandbox-wrapper git enable --global`
- **THEN** all workspaces SHALL have git access enabled by default

#### Scenario: Enable git for workspace
- **WHEN** user runs `npx @kokorolx/ai-sandbox-wrapper git enable --workspace <path>`
- **THEN** the workspace path SHALL be added to `config.json.git.allowedWorkspaces`

#### Scenario: Disable git for workspace
- **WHEN** user runs `npx @kokorolx/ai-sandbox-wrapper git disable --workspace <path>`
- **THEN** the workspace path SHALL be removed from `config.json.git.allowedWorkspaces`

#### Scenario: Show git status
- **WHEN** user runs `npx @kokorolx/ai-sandbox-wrapper git status`
- **THEN** the system SHALL display workspaces with git access enabled

### Requirement: CLI Network Commands
The CLI SHALL provide scripting-friendly commands for network management.

#### Scenario: Add network globally
- **WHEN** user runs `npx @kokorolx/ai-sandbox-wrapper network add <name> --global`
- **THEN** the network name SHALL be added to `config.json.networks.global`

#### Scenario: Add network for workspace
- **WHEN** user runs `npx @kokorolx/ai-sandbox-wrapper network add <name> --workspace <path>`
- **THEN** the network name SHALL be added to `config.json.networks.workspaces.<path>`

#### Scenario: Remove network
- **WHEN** user runs `npx @kokorolx/ai-sandbox-wrapper network remove <name> --global`
- **THEN** the network name SHALL be removed from `config.json.networks.global`

#### Scenario: List networks
- **WHEN** user runs `npx @kokorolx/ai-sandbox-wrapper network list`
- **THEN** the system SHALL display configured networks grouped by scope

### Requirement: Configuration Display
The CLI SHALL provide a command to display the current configuration.

#### Scenario: Show full config
- **WHEN** user runs `npx @kokorolx/ai-sandbox-wrapper config show`
- **THEN** the system SHALL display the current `config.json` contents
- **AND** sensitive values (API keys) SHALL NOT be displayed

#### Scenario: Show config as JSON
- **WHEN** user runs `npx @kokorolx/ai-sandbox-wrapper config show --json`
- **THEN** the system SHALL output valid JSON for parsing by other tools
