## ADDED Requirements

### Requirement: Runtime Port Exposure
The container runtime (`bin/ai-run`) SHALL support exposing container ports to the host via the `PORT` environment variable.

#### Scenario: Single port exposure
- **WHEN** `PORT=3000` is set when running ai-run
- **THEN** the container SHALL map port 3000 from container to host
- **AND** the port SHALL be bound to `127.0.0.1` by default (localhost only)

#### Scenario: Multiple port exposure
- **WHEN** `PORT=3000,5555,5556,5557` is set when running ai-run
- **THEN** the container SHALL map all specified ports from container to host
- **AND** each port SHALL be bound according to the `PORT_BIND` setting

#### Scenario: Invalid port handling
- **WHEN** an invalid port number is specified (e.g., `PORT=99999` or `PORT=abc`)
- **THEN** the invalid port SHALL be skipped with a warning message
- **AND** valid ports in the same list SHALL still be mapped

### Requirement: Port Binding Mode
The container runtime SHALL support configurable port binding mode via the `PORT_BIND` environment variable.

#### Scenario: Localhost binding (default)
- **WHEN** `PORT_BIND` is not set or set to `localhost`
- **THEN** ports SHALL be bound to `127.0.0.1`
- **AND** ports SHALL only be accessible from the host machine

#### Scenario: Network binding
- **WHEN** `PORT_BIND=all` is set
- **THEN** ports SHALL be bound to `0.0.0.0`
- **AND** a security warning SHALL be displayed to the user
- **AND** ports SHALL be accessible from the network

### Requirement: Port Exposure Debug Output
The container runtime SHALL include port configuration in debug output when `AI_RUN_DEBUG=1` is set.

#### Scenario: Debug mode with ports
- **WHEN** `AI_RUN_DEBUG=1` and `PORT=3000,5555` are set
- **THEN** the debug output SHALL show the port mappings being applied
- **AND** the debug output SHALL show the binding mode (localhost or all)
