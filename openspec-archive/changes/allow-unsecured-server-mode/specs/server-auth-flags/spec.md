# server-auth-flags Specification

## Purpose

CLI flags for controlling OpenCode server authentication when running `opencode web` or `opencode serve` through the `ai-run` wrapper.

## Requirements

### Requirement: Password Flag

The `ai-run` command SHALL support a `--password` / `-p` flag to set the OpenCode server password directly from the command line.

#### Scenario: Set password via long flag
- **WHEN** user runs `ai-run opencode web --password mysecret`
- **THEN** the container SHALL receive `-e OPENCODE_SERVER_PASSWORD=mysecret`
- **AND** no password prompt or warning SHALL be displayed

#### Scenario: Set password via short flag
- **WHEN** user runs `ai-run opencode serve -p mysecret`
- **THEN** the container SHALL receive `-e OPENCODE_SERVER_PASSWORD=mysecret`
- **AND** no password prompt or warning SHALL be displayed

#### Scenario: Password flag with spaces
- **WHEN** user runs `ai-run opencode web --password "my secret password"`
- **THEN** the container SHALL receive the full password including spaces
- **AND** the password SHALL be properly quoted in the Docker command

### Requirement: Password Environment Variable Flag

The `ai-run` command SHALL support a `--password-env` flag to read the password from a specified environment variable.

#### Scenario: Read password from custom env var
- **WHEN** user runs `MY_PASSWORD=secret123 ai-run opencode web --password-env MY_PASSWORD`
- **THEN** the container SHALL receive `-e OPENCODE_SERVER_PASSWORD=secret123`
- **AND** no password prompt or warning SHALL be displayed

#### Scenario: Missing environment variable
- **WHEN** user runs `ai-run opencode web --password-env NONEXISTENT_VAR`
- **AND** the environment variable is not set
- **THEN** an error message SHALL be displayed
- **AND** the command SHALL exit with non-zero status

### Requirement: Allow Unsecured Flag

The `ai-run` command SHALL support an `--allow-unsecured` flag to explicitly opt-in to running without a password.

#### Scenario: Suppress warning in non-interactive mode
- **WHEN** user runs `ai-run opencode web --allow-unsecured` in non-interactive mode
- **THEN** no warning about unsecured server SHALL be displayed
- **AND** no password SHALL be set on the container

#### Scenario: Skip interactive prompt
- **WHEN** user runs `ai-run opencode web --allow-unsecured` in interactive mode (TTY attached)
- **THEN** the password selection menu SHALL NOT be displayed
- **AND** no password SHALL be set on the container

### Requirement: Flag Precedence

The authentication flags SHALL follow a defined precedence order when multiple sources are available.

#### Scenario: CLI password overrides environment
- **WHEN** `OPENCODE_SERVER_PASSWORD=envpass` is set in environment
- **AND** user runs `ai-run opencode web --password clipass`
- **THEN** the container SHALL receive `-e OPENCODE_SERVER_PASSWORD=clipass`

#### Scenario: Password-env overrides environment
- **WHEN** `OPENCODE_SERVER_PASSWORD=envpass` is set in environment
- **AND** `CUSTOM_PASS=custompass` is set in environment
- **AND** user runs `ai-run opencode web --password-env CUSTOM_PASS`
- **THEN** the container SHALL receive `-e OPENCODE_SERVER_PASSWORD=custompass`

#### Scenario: Allow-unsecured with existing env password
- **WHEN** `OPENCODE_SERVER_PASSWORD=envpass` is set in environment
- **AND** user runs `ai-run opencode web --allow-unsecured`
- **THEN** the existing password SHALL still be used (allow-unsecured only suppresses warnings)

### Requirement: Flag Scope

The authentication flags SHALL only apply when running OpenCode in web or serve mode.

#### Scenario: Flags ignored for non-web mode
- **WHEN** user runs `ai-run opencode --password secret` (no web/serve subcommand)
- **THEN** the `--password` flag SHALL be passed through to OpenCode as a tool argument
- **AND** no special password handling SHALL occur

#### Scenario: Flags work with serve command
- **WHEN** user runs `ai-run opencode serve --password secret`
- **THEN** the password handling SHALL work identically to `opencode web`
