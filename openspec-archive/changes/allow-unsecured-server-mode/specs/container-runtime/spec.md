## MODIFIED Requirements

### Requirement: OpenCode Web Mode Password Handling

The container runtime (`bin/ai-run`) SHALL support CLI flags for OpenCode server authentication when running `opencode web` or `opencode serve`.

#### Scenario: Password via CLI flag
- **WHEN** user runs `ai-run opencode web --password <value>`
- **THEN** the container SHALL be started with `-e OPENCODE_SERVER_PASSWORD=<value>`
- **AND** the interactive password menu SHALL be skipped
- **AND** no security warning SHALL be displayed

#### Scenario: Password via environment variable flag
- **WHEN** user runs `ai-run opencode web --password-env <VAR_NAME>`
- **AND** the environment variable `<VAR_NAME>` is set
- **THEN** the container SHALL be started with `-e OPENCODE_SERVER_PASSWORD=<value from VAR_NAME>`
- **AND** the interactive password menu SHALL be skipped

#### Scenario: Allow unsecured mode explicitly
- **WHEN** user runs `ai-run opencode web --allow-unsecured`
- **THEN** no password SHALL be set on the container
- **AND** no security warning SHALL be displayed
- **AND** the interactive password menu SHALL be skipped

#### Scenario: Non-interactive without flags (existing behavior)
- **WHEN** user runs `ai-run opencode web` in non-interactive mode
- **AND** no `--password`, `--password-env`, or `--allow-unsecured` flag is provided
- **AND** `OPENCODE_SERVER_PASSWORD` is not set in environment
- **THEN** a warning SHALL be displayed: "OPENCODE_SERVER_PASSWORD not set - server is unsecured"

#### Scenario: Interactive mode without flags (existing behavior)
- **WHEN** user runs `ai-run opencode web` in interactive mode (TTY attached)
- **AND** no `--password`, `--password-env`, or `--allow-unsecured` flag is provided
- **AND** `OPENCODE_SERVER_PASSWORD` is not set in environment
- **THEN** the interactive password menu SHALL be displayed with options:
  1. Generate random password
  2. Enter custom password
  3. No password (unsecured)
