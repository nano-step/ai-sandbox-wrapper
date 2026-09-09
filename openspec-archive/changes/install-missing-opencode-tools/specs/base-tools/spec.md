## ADDED Requirements

### Requirement: fd-find available in container
The base and sandbox container images SHALL include `fd-find` as a pre-installed system package.

#### Scenario: fd-find binary is accessible
- **WHEN** a container is started from the base or sandbox image
- **THEN** the `fdfind` binary SHALL be available in the system PATH
- **AND** running `fdfind --version` SHALL succeed

### Requirement: sqlite3 CLI available in container
The base and sandbox container images SHALL include `sqlite3` as a pre-installed system package.

#### Scenario: sqlite3 can open databases
- **WHEN** a container is started from the base or sandbox image
- **THEN** the `sqlite3` binary SHALL be available in the system PATH
- **AND** the agent user SHALL be able to open and query `.sqlite` database files
