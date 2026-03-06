## MODIFIED Requirements

### Requirement: Base system packages
The base image apt-get install line SHALL include `tmux` alongside the existing system packages (git, curl, ssh, ca-certificates, jq, python3, etc.).

#### Scenario: tmux included in base package installation
- **WHEN** the base Docker image is built
- **THEN** `tmux` SHALL be installed via the primary `apt-get install` command
- **AND** no additional Docker layer SHALL be created for tmux installation
