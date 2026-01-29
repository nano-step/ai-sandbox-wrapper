## MODIFIED Requirements

### Requirement: Clean Command
The CLI SHALL provide a `clean` command for removing AI Sandbox directories using the consolidated path structure.

#### Scenario: Invoke clean command
- **WHEN** user runs `npx @kokorolx/ai-sandbox-wrapper clean`
- **THEN** the system SHALL display an interactive menu of deletable items within `~/.ai-sandbox/`
- **AND** the system SHALL NOT delete anything without user selection

#### Scenario: Help includes clean command
- **WHEN** user runs `npx @kokorolx/ai-sandbox-wrapper help`
- **THEN** the output SHALL list the `clean` command with description

### Requirement: Two-Level Menu Navigation
The CLI SHALL provide a two-level menu for granular control over what to delete, using the new consolidated paths.

#### Scenario: First level - category selection
- **WHEN** the clean command starts
- **THEN** the system SHALL display categories:
  - "Tool caches (cache/)" - safe to delete
  - "Tool configs (home/)" - loses settings
  - "Config files" - loses preferences
  - "Everything (full reset)"

#### Scenario: Second level - tool selection for caches
- **WHEN** user selects "Tool caches"
- **THEN** the system SHALL list all subdirectories in `~/.ai-sandbox/cache/` (e.g., claude/, opencode/, aider/)
- **AND** each tool SHALL show its individual size
- **AND** user SHALL be able to select specific tools or "all"

#### Scenario: Second level - tool selection for configs
- **WHEN** user selects "Tool configs"
- **THEN** the system SHALL list all subdirectories in `~/.ai-sandbox/home/` (e.g., claude/, opencode/)
- **AND** each tool SHALL show its individual size
- **AND** user SHALL be able to select specific tools or "all"

#### Scenario: Second level - config files
- **WHEN** user selects "Config files"
- **THEN** the system SHALL list individual config files/directories within `~/.ai-sandbox/`:
  - `config.json` (network config) - 🟡 Medium
  - `git-allowed` (git preferences) - 🟡 Medium
  - `git-keys/` (SSH key selections) - 🟡 Medium
  - `workspaces` (workspace list) - 🔴 Critical
  - `env` (API keys) - 🔴 Critical
- **AND** user SHALL be able to select specific items

#### Scenario: Full reset option
- **WHEN** user selects "Everything (full reset)"
- **THEN** the system SHALL select the entire `~/.ai-sandbox/` directory for deletion
- **AND** display a prominent warning about losing all configuration

#### Scenario: Back navigation
- **WHEN** user is in second-level menu
- **THEN** user SHALL be able to go back to first level by entering "b" or "back"

### Requirement: Directory Discovery
The CLI SHALL discover and display items within the consolidated `~/.ai-sandbox/` directory.

#### Scenario: Directory exists
- **WHEN** `~/.ai-sandbox/cache/{tool}/` exists
- **THEN** it SHALL appear in the tool caches selection menu with its size

#### Scenario: Directory does not exist
- **WHEN** `~/.ai-sandbox/` does not exist
- **THEN** the system SHALL display "No AI Sandbox data found. Nothing to clean."
- **AND** exit gracefully

#### Scenario: Empty subdirectory
- **WHEN** `~/.ai-sandbox/cache/` exists but is empty
- **THEN** the "Tool caches" category SHALL show "No items found"
