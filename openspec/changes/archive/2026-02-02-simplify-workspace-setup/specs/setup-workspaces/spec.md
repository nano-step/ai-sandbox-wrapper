## ADDED Requirements

### Requirement: optional-workspace-input
The workspace directory input during `setup.sh` should be optional.

#### Scenario: skip-workspace-input
- **WHEN** user is prompted for workspaces in `setup.sh`
- **AND** user presses ENTER without typing anything
- **THEN** script should not fail
- **AND** script should continue to tool selection

### Requirement: default-whitelist-current
If no workspaces are provided, the setup can optionally offer to whitelist the current directory.

#### Scenario: whitelist-current-by-default
- **WHEN** user provides no workspaces
- **THEN** setup continues normally
- **AND** the whitelisting is handled on-demand during first run of a tool
