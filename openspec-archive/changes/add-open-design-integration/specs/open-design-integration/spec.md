## ADDED Requirements

### Requirement: Persistent open-design Daemon Container

The system SHALL provide a long-running Docker container named `ai-open-design` that hosts the open-design HTTP daemon on port 7456, with state persisted in a Docker named volume across container restarts, image rebuilds, and host reboots.

#### Scenario: First-time installation

- **WHEN** a user runs `bash lib/install-open-design.sh`
- **THEN** the system SHALL build a Docker image `ai-open-design:latest` based on the upstream open-design daemon image with `OD_BIND_HOST=0.0.0.0` set
- **AND** the system SHALL NOT start the daemon yet (start is a separate explicit action)

#### Scenario: Starting the daemon

- **GIVEN** the image `ai-open-design:latest` exists and `~/.ai-sandbox/env` contains `OD_API_TOKEN`
- **WHEN** the user runs `ai-run open-design start`
- **THEN** the system SHALL run a detached container named `ai-open-design` attached to Docker network `ai-sandbox`
- **AND** the system SHALL mount Docker volume `ai-open-design-data` at `/app/.od` inside the container
- **AND** the system SHALL pass `OD_API_TOKEN` from `~/.ai-sandbox/env` to the container as an environment variable
- **AND** the system SHALL NOT publish port 7456 to the host machine unless the `--expose` flag is given
- **AND** the daemon SHALL respond with HTTP 200 to `GET /api/health` within 10 seconds

#### Scenario: Daemon survives container restarts

- **GIVEN** the daemon is running with `--restart unless-stopped`
- **WHEN** the Docker engine restarts or the host reboots
- **THEN** the daemon container SHALL be restarted automatically by Docker
- **AND** the persisted SQLite database, project files, and artifacts SHALL be intact

#### Scenario: Stopping the daemon

- **WHEN** the user runs `ai-run open-design stop`
- **THEN** the system SHALL stop the `ai-open-design` container via `docker stop`
- **AND** the container SHALL NOT be removed (so flags and config survive)
- **AND** the named volume `ai-open-design-data` SHALL retain all data
- **AND** the daemon SHALL NOT auto-restart on subsequent Docker engine restarts until the user runs `start` again

### Requirement: Persistent API Token

The system SHALL generate a 256-bit random bearer token on first initialization, persist it in `~/.ai-sandbox/env` as `OD_API_TOKEN`, and reuse the same token across all subsequent daemon starts and agent container launches.

#### Scenario: First-time init generates token

- **GIVEN** `~/.ai-sandbox/env` does not contain `OD_API_TOKEN`
- **WHEN** the user runs `ai-run open-design init`
- **THEN** the system SHALL generate a cryptographically random 256-bit token via `openssl rand -hex 32`
- **AND** the system SHALL append `OD_API_TOKEN=<value>` to `~/.ai-sandbox/env`
- **AND** the system SHALL append `OD_DAEMON_URL=http://ai-open-design:7456` to `~/.ai-sandbox/env`
- **AND** the system SHALL set file mode of `~/.ai-sandbox/env` to `600`

#### Scenario: Subsequent init is idempotent

- **GIVEN** `~/.ai-sandbox/env` already contains `OD_API_TOKEN`
- **WHEN** the user runs `ai-run open-design init` again without `--force`
- **THEN** the system SHALL NOT overwrite the existing token
- **AND** the system SHALL print a notice that the token already exists

#### Scenario: Forced token rotation

- **GIVEN** `~/.ai-sandbox/env` already contains `OD_API_TOKEN`
- **WHEN** the user runs `ai-run open-design init --force`
- **THEN** the system SHALL prompt for confirmation
- **AND** on confirmation, the system SHALL replace the existing `OD_API_TOKEN` line with a freshly generated token
- **AND** the system SHALL print a warning that running daemon and agent containers must be restarted to pick up the new token

### Requirement: Shared Docker Network for Service Discovery

The system SHALL create and use a Docker network named `ai-sandbox` so all wrapper-launched containers (open-design daemon and any agent container started via `ai-run`) can address each other by container name without exposing ports to the host.

#### Scenario: Network created lazily

- **GIVEN** the Docker network `ai-sandbox` does not exist
- **WHEN** the user runs any `ai-run` command that launches a container
- **THEN** the system SHALL create the `ai-sandbox` network as a bridge network
- **AND** the launched container SHALL join the `ai-sandbox` network

#### Scenario: Network reused across runs

- **GIVEN** the Docker network `ai-sandbox` already exists
- **WHEN** the user runs `ai-run open-design start` or `ai-run opencode`
- **THEN** the system SHALL NOT recreate the network
- **AND** all launched containers SHALL join the existing network

#### Scenario: Agent container resolves daemon by name

- **GIVEN** the daemon is running as `ai-open-design` on network `ai-sandbox`
- **AND** an agent container is launched via `ai-run opencode` (also on `ai-sandbox`)
- **WHEN** the agent container executes `curl http://ai-open-design:7456/api/health`
- **THEN** the request SHALL succeed with HTTP 200

### Requirement: Automatic Token and URL Injection into Agent Containers

The system SHALL inject `OD_API_TOKEN` and `OD_DAEMON_URL` environment variables into every agent container launched via `ai-run`, sourced from `~/.ai-sandbox/env`, with no manual export required by the user.

#### Scenario: Agent shell sees env vars immediately

- **GIVEN** `~/.ai-sandbox/env` contains `OD_API_TOKEN=...` and `OD_DAEMON_URL=...`
- **WHEN** the user runs `ai-run opencode`
- **THEN** an interactive shell inside the agent container SHALL have `$OD_API_TOKEN` and `$OD_DAEMON_URL` set
- **AND** the user SHALL NOT need to run any `export` command

#### Scenario: Agent started before daemon still works

- **GIVEN** an agent container is running, started before the daemon
- **AND** `$OD_API_TOKEN` was already injected from `~/.ai-sandbox/env` at container start
- **WHEN** the user runs `ai-run open-design start` in a separate terminal
- **THEN** the existing agent container SHALL reach the daemon via `$OD_DAEMON_URL` immediately, without restart
- **AND** the daemon SHALL accept the agent's bearer token

### Requirement: Read-Only Artifact Volume for Agents

The system SHALL mount the open-design data volume `ai-open-design-data` into every agent container at `/workspace/.od` in read-only mode, so agents can read generated artifacts directly from the filesystem but cannot corrupt daemon state.

#### Scenario: Agent reads artifact from filesystem

- **GIVEN** the daemon has generated an artifact at `/app/.od/projects/abc/index.html`
- **WHEN** an agent container is launched via `ai-run opencode`
- **THEN** the file SHALL be visible at `/workspace/.od/projects/abc/index.html` inside the agent
- **AND** the agent SHALL be able to read it (`cat`, `less`, etc.)

#### Scenario: Agent cannot modify artifacts

- **GIVEN** an agent container has `/workspace/.od` mounted read-only
- **WHEN** the agent attempts to write to `/workspace/.od/test`
- **THEN** the operation SHALL fail with a read-only filesystem error
- **AND** the daemon's SQLite database SHALL be unaffected

#### Scenario: Volume mount skipped when not initialized

- **GIVEN** the user has never run `ai-run open-design init` or `start`
- **AND** the volume `ai-open-design-data` does not exist
- **WHEN** the user runs `ai-run opencode`
- **THEN** the system SHALL launch the agent container without the `/workspace/.od` mount
- **AND** the agent container SHALL launch successfully

### Requirement: Lifecycle Subcommands

The system SHALL provide `init`, `start`, `stop`, `restart`, `status`, and `logs` subcommands under `ai-run open-design`, mirroring the lifecycle expectations of a long-running service.

#### Scenario: status reports running daemon

- **GIVEN** the daemon is running
- **WHEN** the user runs `ai-run open-design status`
- **THEN** the system SHALL print container state (`running`), uptime, network membership, port mapping (or "not exposed"), and a masked indicator that `OD_API_TOKEN` is set
- **AND** the system SHALL invoke the health endpoint and report HTTP status

#### Scenario: status reports stopped daemon

- **GIVEN** the daemon container exists but is stopped (or does not exist)
- **WHEN** the user runs `ai-run open-design status`
- **THEN** the system SHALL print `stopped` (or `not installed`) and exit with code 0
- **AND** the system SHALL hint at the next step (`Run: ai-run open-design start`)

#### Scenario: logs follow daemon output

- **WHEN** the user runs `ai-run open-design logs -f`
- **THEN** the system SHALL stream `docker logs -f ai-open-design` until interrupted

### Requirement: Optional Host Port Exposure

The system SHALL allow the user to optionally expose the daemon on host port 7456 via an explicit `--expose` flag on `ai-run open-design start`, supporting use cases where a host browser needs to reach the daemon UI directly.

#### Scenario: Default is internal-only

- **WHEN** the user runs `ai-run open-design start` without `--expose`
- **THEN** the daemon SHALL NOT bind to any host port
- **AND** the daemon SHALL be reachable only from containers on network `ai-sandbox`

#### Scenario: Explicit exposure

- **WHEN** the user runs `ai-run open-design start --expose`
- **THEN** the system SHALL publish container port 7456 to host port 7456
- **AND** the daemon SHALL be reachable at `http://localhost:7456` from the host
- **AND** the daemon SHALL still be reachable at `http://ai-open-design:7456` from sandbox containers

#### Scenario: Custom host port

- **WHEN** the user runs `ai-run open-design start --expose --port 17456`
- **THEN** the system SHALL publish container port 7456 to host port 17456

### Requirement: Helper Commands in Base Image

The base image SHALL provide `od-status` and `od-health` shell helpers at `/usr/local/bin` so agents (or users via `docker exec`) can quickly check daemon reachability without crafting curl arguments by hand.

#### Scenario: od-health reports daemon up

- **GIVEN** `$OD_DAEMON_URL` and `$OD_API_TOKEN` are set in the agent shell
- **AND** the daemon is reachable
- **WHEN** the user runs `od-health`
- **THEN** the command SHALL exit 0 and print the JSON response from `/api/health`

#### Scenario: od-health reports daemon down

- **GIVEN** the daemon is not running
- **WHEN** the user runs `od-health`
- **THEN** the command SHALL exit non-zero
- **AND** the command SHALL print a clear message ("daemon unreachable: connection refused")

#### Scenario: od-status summarizes connection

- **WHEN** the user runs `od-status`
- **THEN** the command SHALL print: the daemon URL, whether the token env var is set (masked), and the result of `od-health` in one line

### Requirement: No Breaking Changes to Existing Tools

The integration SHALL NOT break any existing tool's behavior. All existing `ai-run <tool>` invocations SHALL continue to work identically before and after this change.

#### Scenario: ai-run opencode without daemon

- **GIVEN** the daemon has never been initialized
- **WHEN** the user runs `ai-run opencode`
- **THEN** the OpenCode TUI SHALL launch normally
- **AND** the user SHALL be able to use OpenCode for any purpose unrelated to open-design

#### Scenario: ai-run claude existing workflow

- **WHEN** the user runs `ai-run claude --version`
- **THEN** the output SHALL be identical to the behavior before this change
- **AND** the container SHALL exit cleanly after printing the version
