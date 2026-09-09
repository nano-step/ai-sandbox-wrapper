## ADDED Requirements

### Requirement: Automatic Migration Detection
The system SHALL automatically detect when migration from old paths to new paths is needed.

#### Scenario: Old paths exist, new paths don't
- **WHEN** old `.ai-*` paths exist in home directory
- **AND** new `~/.ai-sandbox/` subdirectories don't exist
- **THEN** the system SHALL trigger automatic migration

#### Scenario: New paths already exist
- **WHEN** new `~/.ai-sandbox/` structure already exists
- **THEN** the system SHALL skip migration
- **AND** use new paths directly

#### Scenario: Both old and new paths exist
- **WHEN** both old `.ai-*` paths and new `~/.ai-sandbox/` paths exist
- **THEN** the system SHALL prefer new paths
- **AND** display a warning about orphaned old paths

### Requirement: Migration Execution
The system SHALL migrate files from old paths to new consolidated structure.

#### Scenario: Migrate cache directory
- **WHEN** `~/.ai-cache/` exists
- **THEN** the system SHALL move it to `~/.ai-sandbox/cache/`

#### Scenario: Migrate home directory
- **WHEN** `~/.ai-home/` exists
- **THEN** the system SHALL move it to `~/.ai-sandbox/home/`

#### Scenario: Migrate workspaces file
- **WHEN** `~/.ai-workspaces` exists
- **THEN** the system SHALL move it to `~/.ai-sandbox/workspaces`

#### Scenario: Migrate env file
- **WHEN** `~/.ai-env` exists
- **THEN** the system SHALL move it to `~/.ai-sandbox/env`

#### Scenario: Migrate git-allowed file
- **WHEN** `~/.ai-git-allowed` exists
- **THEN** the system SHALL move it to `~/.ai-sandbox/git-allowed`

#### Scenario: Migrate git-keys files
- **WHEN** `~/.ai-git-keys-*` files exist
- **THEN** the system SHALL create `~/.ai-sandbox/git-keys/` directory
- **AND** move each file into it (stripping the `.ai-git-keys-` prefix)

### Requirement: Migration Marker
The system SHALL track migration completion to prevent re-migration.

#### Scenario: Create migration marker
- **WHEN** migration completes successfully
- **THEN** the system SHALL create `~/.ai-sandbox/.migrated` file
- **AND** the file SHALL contain the migration timestamp

#### Scenario: Skip if marker exists
- **WHEN** `~/.ai-sandbox/.migrated` file exists
- **THEN** the system SHALL skip migration detection entirely

### Requirement: Migration Error Handling
The system SHALL handle migration errors gracefully.

#### Scenario: Permission denied on move
- **WHEN** a file cannot be moved due to permissions
- **THEN** the system SHALL display an error message with the specific file
- **AND** continue migrating other files
- **AND** NOT create the migration marker (incomplete migration)

#### Scenario: Disk full
- **WHEN** disk is full during migration
- **THEN** the system SHALL display an error message
- **AND** suggest freeing disk space
- **AND** NOT create the migration marker

#### Scenario: Partial migration recovery
- **WHEN** migration was interrupted (no marker, some files moved)
- **THEN** the system SHALL detect remaining old paths
- **AND** continue migration from where it left off
