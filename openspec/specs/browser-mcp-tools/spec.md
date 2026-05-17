# browser-mcp-tools Specification

## Purpose
Optional MCP (Model Context Protocol) servers for browser automation that enable AI agents running inside the sandbox container to control browsers for web testing, debugging, and performance analysis.

## ADDED Requirements

### Requirement: Chrome DevTools MCP Installation
The base image build system SHALL support optional installation of Chrome DevTools MCP via the `INSTALL_CHROME_DEVTOOLS_MCP` environment variable.

#### Scenario: Chrome DevTools MCP installation enabled
- **WHEN** `INSTALL_CHROME_DEVTOOLS_MCP=1` is set during base image build
- **THEN** the `chrome-devtools-mcp` npm package SHALL be installed globally
- **AND** Puppeteer's bundled Chrome browser SHALL be downloaded to `/opt/puppeteer-cache/`
- **AND** the `PUPPETEER_CACHE_DIR` environment variable SHALL be set to `/opt/puppeteer-cache`
- **AND** the `CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS` environment variable SHALL be set to `1`
- **AND** the `/opt/puppeteer-cache/` directory SHALL have permissions `755` for non-root access

#### Scenario: Chrome DevTools MCP installation disabled (default)
- **WHEN** `INSTALL_CHROME_DEVTOOLS_MCP` is not set or set to `0`
- **THEN** no Chrome DevTools MCP dependencies SHALL be installed
- **AND** the base image size SHALL remain unchanged

#### Scenario: Chrome DevTools MCP verification
- **WHEN** Chrome DevTools MCP is installed in the container
- **THEN** running `chrome-devtools-mcp --help` SHALL succeed and display usage information
- **AND** the MCP server SHALL be executable by the non-root `agent` user

#### Scenario: Chrome DevTools MCP headless operation
- **WHEN** Chrome DevTools MCP is started with `--headless --isolated` flags
- **THEN** Chrome SHALL launch in headless mode without requiring a display server
- **AND** the browser profile SHALL be temporary and cleaned up after session ends

### Requirement: Playwright MCP Installation
The base image build system SHALL support optional installation of Playwright MCP via the `INSTALL_PLAYWRIGHT_MCP` environment variable.

#### Scenario: Playwright MCP installation enabled
- **WHEN** `INSTALL_PLAYWRIGHT_MCP=1` is set during base image build
- **THEN** the `@playwright/mcp` npm package SHALL be installed globally
- **AND** Playwright's Chromium browser SHALL be downloaded to `/opt/playwright-browsers/`
- **AND** Playwright's Chromium system dependencies SHALL be installed
- **AND** the `PLAYWRIGHT_BROWSERS_PATH` environment variable SHALL be set to `/opt/playwright-browsers`
- **AND** the `/opt/playwright-browsers/` directory SHALL have permissions `755` for non-root access

#### Scenario: Playwright MCP installation disabled (default)
- **WHEN** `INSTALL_PLAYWRIGHT_MCP` is not set or set to `0`
- **THEN** no Playwright MCP dependencies SHALL be installed
- **AND** the base image size SHALL remain unchanged

#### Scenario: Playwright MCP verification
- **WHEN** Playwright MCP is installed in the container
- **THEN** running `npx @playwright/mcp --help` SHALL succeed and display usage information
- **AND** the MCP server SHALL be executable by the non-root `agent` user

#### Scenario: Playwright MCP headless operation
- **WHEN** Playwright MCP is started with `--headless --browser chromium --no-sandbox` flags
- **THEN** Chromium SHALL launch in headless mode without requiring a display server
- **AND** the browser SHALL operate without sandbox restrictions (safe in container context)

### Requirement: MCP Tools Selection UI
The setup.sh installer SHALL provide a user interface for selecting MCP tools to install.

#### Scenario: MCP Tools section displayed
- **WHEN** user runs `setup.sh` interactively
- **THEN** an "MCP Tools" section SHALL be displayed after other optional tool selections
- **AND** the section SHALL explain that these tools enable AI agents to control browsers

#### Scenario: Chrome DevTools MCP selection
- **WHEN** user is prompted for Chrome DevTools MCP installation
- **THEN** the prompt SHALL display:
  - Tool name: "Chrome DevTools MCP (Google)"
  - Key features: Performance profiling, Core Web Vitals, detailed console/network inspection
  - Approximate size impact: ~400MB
- **AND** user input of `y` or `Y` SHALL set `INSTALL_CHROME_DEVTOOLS_MCP=1`

#### Scenario: Playwright MCP selection
- **WHEN** user is prompted for Playwright MCP installation
- **THEN** the prompt SHALL display:
  - Tool name: "Playwright MCP (Microsoft)"
  - Key features: Multi-browser support, TypeScript code generation, vision mode
  - Approximate size impact: ~300MB (Chromium only)
- **AND** user input of `y` or `Y` SHALL set `INSTALL_PLAYWRIGHT_MCP=1`

### Requirement: Container Security Compatibility
Both MCP tools SHALL operate within the sandbox's security constraints.

#### Scenario: Non-root user operation
- **WHEN** an MCP tool is started by the `agent` user (UID 1001)
- **THEN** the tool SHALL successfully launch and control the browser
- **AND** no root privileges SHALL be required

#### Scenario: CAP_DROP=ALL compatibility
- **WHEN** the container runs with `CAP_DROP=ALL` security setting
- **THEN** both MCP tools SHALL operate correctly using `--no-sandbox` browser flag
- **AND** no capability-related errors SHALL occur

#### Scenario: Shared memory handling
- **WHEN** Chrome/Chromium is launched inside the container
- **THEN** the browser SHALL use `/tmp` instead of `/dev/shm` for shared memory
- **AND** no "out of memory" errors SHALL occur due to default Docker /dev/shm size (64MB)

### Requirement: Privacy and Telemetry
MCP tools SHALL respect user privacy within the sandbox environment.

#### Scenario: Chrome DevTools MCP telemetry disabled
- **WHEN** Chrome DevTools MCP is installed via the base image
- **THEN** the `CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS=1` environment variable SHALL be set
- **AND** no usage statistics SHALL be sent to Google servers

#### Scenario: Playwright MCP privacy
- **WHEN** Playwright MCP is installed via the base image
- **THEN** no telemetry or usage data SHALL be collected (Playwright MCP has no telemetry)
