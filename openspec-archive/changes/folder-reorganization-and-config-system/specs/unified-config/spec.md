# unified-config Specification

## ADDED Requirements

### Requirement: Unified Configuration File
The AI Sandbox SHALL use a single configuration file at `~/.ai-sandbox/config.json` for all settings.

#### Scenario: Config file creation
- **WHEN** `setup.sh` is run and no config file exists
- **THEN** the system SHALL create `~/.ai-sandbox/config.json` with default structure
- **AND** the file SHALL have permissions 600 (owner read/write only)

#### Scenario: Config file schema
- **WHEN** the config file is read
- **THEN** it SHALL contain a `version` field with integer value
- **AND** it SHALL contain a `workspaces` array of directory paths
- **AND** it SHALL contain a `git` object with access settings
- **AND** it SHALL contain a `networks` object with network settings

### Requirement: Workspaces Configuration
The unified config SHALL store the list of whitelisted workspace directories.

#### Scenario: Reading workspaces from config
- **WHEN** `ai-run` checks if the current directory is allowed
- **THEN** it SHALL read the `workspaces` array from `config.json`
- **AND** each entry SHALL be an absolute directory path

#### Scenario: Legacy workspaces file migration
- **WHEN** `~/.ai-sandbox/workspaces` file exists and `config.json` has no workspaces
- **THEN** the system SHALL read the legacy file and populate `config.json.workspaces`
- **AND** the legacy file SHALL be preserved for backward compatibility

#### Scenario: Adding a workspace
- **WHEN** a user confirms whitelisting a new directory
- **THEN** the directory path SHALL be appended to `config.json.workspaces`
- **AND** duplicate paths SHALL NOT be added

### Requirement: Git Access Configuration
The unified config SHALL store Git access permissions per workspace.

#### Scenario: Git allowed workspaces
- **WHEN** `ai-run` checks if Git access is enabled for a workspace
- **THEN** it SHALL check if the workspace path exists in `config.json.git.allowedWorkspaces`

#### Scenario: Git key selections
- **WHEN** a user selects SSH keys for a workspace
- **THEN** the selection SHALL be stored in `config.json.git.keySelections`
- **AND** the key SHALL be the MD5 hash of the workspace path
- **AND** the value SHALL be an array of key filenames

#### Scenario: Legacy git-allowed file migration
- **WHEN** `~/.ai-sandbox/git-allowed` file exists
- **THEN** the system SHALL read workspace paths and populate `config.json.git.allowedWorkspaces`

### Requirement: Network Configuration
The unified config SHALL store Docker network access settings.

#### Scenario: Global network access
- **WHEN** networks are configured globally
- **THEN** they SHALL be stored in `config.json.networks.global` as an array

#### Scenario: Per-workspace network access
- **WHEN** networks are configured for a specific workspace
- **THEN** they SHALL be stored in `config.json.networks.workspaces.<path>` as an array

#### Scenario: Network precedence
- **WHEN** both global and workspace-specific networks are configured
- **THEN** workspace-specific networks SHALL take precedence
- **AND** global networks SHALL be ignored for that workspace

### Requirement: Environment Variables File
The AI Sandbox SHALL support a separate `env` file for sensitive API keys.

#### Scenario: Env file location
- **WHEN** `ai-run` starts a container
- **THEN** it SHALL read environment variables from `~/.ai-sandbox/env`
- **AND** the file SHALL be passed to Docker via `--env-file`

#### Scenario: Env file permissions
- **WHEN** the env file is created
- **THEN** it SHALL have permissions 600 (owner read/write only)

#### Scenario: Env file format
- **WHEN** the env file is read
- **THEN** each line SHALL be in `KEY=value` format
- **AND** lines starting with `#` SHALL be treated as comments
