## ADDED Requirements

### Requirement: SSH agent socket forwarding
The system SHALL detect the host's SSH agent socket and forward it into the container instead of copying private key files.

#### Scenario: SSH agent is available on Linux
- **GIVEN** the environment variable `SSH_AUTH_SOCK` is set and points to an existing socket
- **WHEN** the container is started with Git access enabled
- **THEN** the system SHALL mount the socket at `/ssh-agent` inside the container
- **AND** the system SHALL set `SSH_AUTH_SOCK=/ssh-agent` as a container environment variable
- **AND** the system SHALL NOT copy any private key files into the container

#### Scenario: SSH agent is available on macOS Docker Desktop
- **GIVEN** the host OS is macOS and `/run/host-services/ssh-auth.sock` exists
- **WHEN** the container is started with Git access enabled
- **THEN** the system SHALL mount the Docker Desktop SSH socket at `/ssh-agent` inside the container
- **AND** the system SHALL set `SSH_AUTH_SOCK=/ssh-agent` as a container environment variable

#### Scenario: SSH agent is not available
- **GIVEN** no SSH agent socket is detected (no `SSH_AUTH_SOCK` or socket file missing)
- **WHEN** the container is started with Git access enabled
- **THEN** the system SHALL fall back to the existing key-copy behavior
- **AND** the system SHALL print a security warning recommending ssh-agent usage

#### Scenario: known_hosts and config still mounted
- **GIVEN** SSH agent forwarding is active
- **WHEN** the container is started
- **THEN** the system SHALL still copy and mount `known_hosts` and filtered SSH config
- **AND** these files SHALL be mounted read-only at `/home/agent/.ssh/`
