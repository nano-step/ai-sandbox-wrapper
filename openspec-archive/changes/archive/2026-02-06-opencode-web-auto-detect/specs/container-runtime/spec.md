# container-runtime Specification (Delta)

## ADDED Requirements

### Requirement: Expose Flag Port Exposure
The container runtime (`bin/ai-run`) SHALL support exposing container ports to the host via the `--expose` / `-e` command-line flag.

#### Scenario: Single port with expose flag
- **WHEN** user runs `ai-run opencode --expose 3000`
- **THEN** the container SHALL map port 3000 from container to host
- **AND** the port SHALL be bound to `127.0.0.1` by default (localhost only)

#### Scenario: Multiple ports with expose flag
- **WHEN** user runs `ai-run opencode --expose 3000,5555,5556`
- **THEN** the container SHALL map all specified ports from container to host
- **AND** each port SHALL be bound according to the `PORT_BIND` setting

#### Scenario: Short flag form
- **WHEN** user runs `ai-run opencode -e 3000,4000`
- **THEN** the container SHALL map ports 3000 and 4000 from container to host

#### Scenario: Invalid port in expose flag
- **WHEN** user runs `ai-run opencode --expose 3000,99999,abc,5000`
- **THEN** the invalid ports (99999, abc) SHALL be skipped with warning messages
- **AND** valid ports (3000, 5000) SHALL still be mapped

### Requirement: Port Conflict Detection
The container runtime SHALL pre-check if requested ports are already in use and fail fast with a helpful error message before attempting to start the container.

#### Scenario: Port in use by host process
- **WHEN** user runs `ai-run opencode --expose 3000`
- **AND** port 3000 is already in use by another process on the host
- **THEN** the runtime SHALL detect the conflict before starting Docker
- **AND** the runtime SHALL display: `❌ ERROR: Port 3000 is already in use by process <name> (PID: <pid>)`
- **AND** the runtime SHALL exit with non-zero status
- **AND** the container SHALL NOT be started

#### Scenario: Port in use by another Docker container
- **WHEN** user runs `ai-run opencode --expose 3000`
- **AND** port 3000 is already mapped by another Docker container
- **THEN** the runtime SHALL detect the conflict
- **AND** the runtime SHALL display: `❌ ERROR: Port 3000 is already in use by container <name>`
- **AND** the runtime SHALL exit with non-zero status

#### Scenario: Multiple ports with one conflict
- **WHEN** user runs `ai-run opencode --expose 3000,4000,5000`
- **AND** port 4000 is already in use
- **THEN** the runtime SHALL report the conflict for port 4000
- **AND** the runtime SHALL exit with non-zero status
- **AND** no ports SHALL be exposed (fail-fast behavior)

#### Scenario: Port check cross-platform support
- **WHEN** user runs ai-run with port exposure on macOS or Linux
- **THEN** the runtime SHALL use `lsof -i :PORT` if available
- **OR** the runtime SHALL fall back to `netstat -tuln | grep :PORT`
- **AND** the port check SHALL work on both platforms

#### Scenario: Port check tool unavailable
- **WHEN** neither `lsof` nor `netstat` is available on the system
- **THEN** the runtime SHALL skip the port conflict check
- **AND** the runtime SHALL display: `⚠️ WARNING: Cannot check port availability (lsof/netstat not found)`
- **AND** the container SHALL proceed to start (let Docker handle conflicts)

### Requirement: PORT Environment Variable Deprecation
The container runtime SHALL continue to support the `PORT` environment variable for backward compatibility, but SHALL display a deprecation warning.

#### Scenario: PORT variable with deprecation warning
- **WHEN** user runs `PORT=3000 ai-run opencode`
- **THEN** the container SHALL map port 3000 from container to host
- **AND** the runtime SHALL display: `⚠️ WARNING: PORT environment variable is deprecated. Use --expose flag instead.`

#### Scenario: Expose flag takes precedence over PORT
- **WHEN** user runs `PORT=3000 ai-run opencode --expose 4000`
- **THEN** the container SHALL map port 4000 (from --expose flag)
- **AND** the container SHALL also map port 3000 (from PORT variable)
- **AND** the deprecation warning SHALL be displayed

#### Scenario: PORT variable in non-interactive mode
- **WHEN** user runs `PORT=3000 ai-run opencode` in a script (non-interactive)
- **THEN** the deprecation warning SHALL still be displayed to stderr
- **AND** the port SHALL be mapped normally

## MODIFIED Requirements

### Requirement: Runtime Port Exposure
The container runtime (`bin/ai-run`) SHALL support exposing container ports to the host via the `--expose` flag (primary) or `PORT` environment variable (deprecated).

#### Scenario: Single port exposure
- **WHEN** `--expose 3000` flag is provided when running ai-run
- **THEN** the container SHALL map port 3000 from container to host
- **AND** the port SHALL be bound to `127.0.0.1` by default (localhost only)

#### Scenario: Multiple port exposure
- **WHEN** `--expose 3000,5555,5556,5557` flag is provided when running ai-run
- **THEN** the container SHALL map all specified ports from container to host
- **AND** each port SHALL be bound according to the `PORT_BIND` setting

#### Scenario: Invalid port handling
- **WHEN** an invalid port number is specified (e.g., `--expose 99999` or `--expose abc`)
- **THEN** the invalid port SHALL be skipped with a warning message
- **AND** valid ports in the same list SHALL still be mapped

### Requirement: Port Exposure Debug Output
The container runtime SHALL include port configuration in debug output when `AI_RUN_DEBUG=1` is set.

#### Scenario: Debug mode with ports
- **WHEN** `AI_RUN_DEBUG=1` is set and `--expose 3000,5555` flag is provided
- **THEN** the debug output SHALL show the port mappings being applied
- **AND** the debug output SHALL show the binding mode (localhost or all)
- **AND** the debug output SHALL show the source of ports (--expose flag, PORT env, or auto-detected)
