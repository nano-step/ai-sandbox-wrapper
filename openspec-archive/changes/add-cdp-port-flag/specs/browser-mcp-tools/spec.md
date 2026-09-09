## ADDED Requirements

### Requirement: Manual CDP Port Configuration
The `ai-run` script SHALL accept a Chrome DevTools Protocol (CDP) port via a `--cdp-port` flag or `CHROME_CDP_PORT` environment variable, overriding the auto-computed port.

#### Scenario: --cdp-port flag specifies a port
- **WHEN** user runs `ai-run opencode --cdp-port 9222`
- **THEN** Chrome SHALL be launched with `--remote-debugging-port=9222`
- **AND** the MCP config entry key SHALL use port 9222 (e.g., `playwright_port_9222`)
- **AND** the container env vars `PLAYWRIGHT_PORT`, `PLAYWRIGHT_MCP_NAME`, and `CHROME_DEVTOOLS_MCP_NAME` SHALL reflect port 9222

#### Scenario: CHROME_CDP_PORT env var specifies a port
- **WHEN** environment variable `CHROME_CDP_PORT=9222` is set
- **AND** `--cdp-port` flag is NOT provided
- **THEN** Chrome SHALL be launched with `--remote-debugging-port=9222`
- **AND** all MCP config entries and container env vars SHALL use port 9222

#### Scenario: --cdp-port flag overrides CHROME_CDP_PORT env var
- **WHEN** `CHROME_CDP_PORT=19222` is set in environment
- **AND** user runs `ai-run opencode --cdp-port 9333`
- **THEN** Chrome SHALL be launched on port 9333 (flag takes precedence over env var)

#### Scenario: Neither flag nor env var provided (default behavior)
- **WHEN** neither `--cdp-port` nor `CHROME_CDP_PORT` is set
- **THEN** port SHALL be auto-computed as `19222 + (hash(container_name) % 100)` (unchanged behavior)

#### Scenario: Manual port with reuse-if-alive probe
- **WHEN** user specifies `--cdp-port 9222`
- **AND** Chrome is already running with CDP on port 9222
- **THEN** `ai-run` SHALL reuse the existing Chrome instance (not launch a new one)
- **AND** MCP config entry SHALL point to port 9222

#### Scenario: Manual port with no running Chrome
- **WHEN** user specifies `--cdp-port 9222`
- **AND** no Chrome instance is running on port 9222
- **THEN** `ai-run` SHALL launch Chrome with `--remote-debugging-port=9222`
- **AND** the Chrome profile directory SHALL be `$SANDBOX_DIR/chrome-profile-9222`

#### Scenario: Port out of range
- **WHEN** user specifies `--cdp-port 0` or `--cdp-port 99999`
- **THEN** `ai-run` SHALL print an error message and exit with status 1
- **AND** the error message SHALL state the valid range (1–65535)

#### Scenario: --cdp-port without a numeric value
- **WHEN** user runs `ai-run opencode --cdp-port` (no value)
- **THEN** `ai-run` SHALL print an error message and exit with status 1

### Requirement: Help Text for CDP Port
The `--help-env` output of `ai-run` SHALL document the `CHROME_CDP_PORT` environment variable and the `--cdp-port` flag.

#### Scenario: --help-env displays CDP port info
- **WHEN** user runs `ai-run --help-env`
- **THEN** the output SHALL include a line documenting `CHROME_CDP_PORT` with the default behavior and valid range
