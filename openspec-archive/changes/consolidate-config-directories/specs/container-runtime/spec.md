## ADDED Requirements

### Requirement: Consolidated Directory Structure
The container runtime SHALL use the consolidated `~/.ai-sandbox/` directory structure for all configuration and cache paths.

#### Scenario: Cache directory path
- **WHEN** the container runtime needs tool cache storage
- **THEN** it SHALL use `~/.ai-sandbox/cache/{tool}/` instead of `~/.ai-cache/{tool}/`

#### Scenario: Home directory path
- **WHEN** the container runtime needs tool configuration storage
- **THEN** it SHALL use `~/.ai-sandbox/home/{tool}/` instead of `~/.ai-home/{tool}/`

#### Scenario: Workspaces file path
- **WHEN** the container runtime reads whitelisted workspaces
- **THEN** it SHALL read from `~/.ai-sandbox/workspaces` instead of `~/.ai-workspaces`

#### Scenario: Environment file path
- **WHEN** the container runtime reads API keys
- **THEN** it SHALL read from `~/.ai-sandbox/env` instead of `~/.ai-env`

#### Scenario: Git allowed file path
- **WHEN** the container runtime checks git-enabled workspaces
- **THEN** it SHALL read from `~/.ai-sandbox/git-allowed` instead of `~/.ai-git-allowed`

#### Scenario: Git keys directory path
- **WHEN** the container runtime reads SSH key selections
- **THEN** it SHALL read from `~/.ai-sandbox/git-keys/{hash}` instead of `~/.ai-git-keys-{hash}`

#### Scenario: Network config path
- **WHEN** the container runtime reads network configuration
- **THEN** it SHALL read from `~/.ai-sandbox/config.json` (unchanged)

### Requirement: Directory Auto-Creation
The container runtime SHALL automatically create required directories if they don't exist.

#### Scenario: Create cache directory
- **WHEN** `~/.ai-sandbox/cache/{tool}/` doesn't exist
- **AND** the tool is being run
- **THEN** the system SHALL create the directory with appropriate permissions

#### Scenario: Create home directory
- **WHEN** `~/.ai-sandbox/home/{tool}/` doesn't exist
- **AND** the tool is being run
- **THEN** the system SHALL create the directory with appropriate permissions

#### Scenario: Create base sandbox directory
- **WHEN** `~/.ai-sandbox/` doesn't exist
- **THEN** the system SHALL create it before any other operations
