# base-image Specification (Delta)

## ADDED Requirements

### Requirement: Chrome DevTools MCP Support
The base image build system SHALL support optional installation of Chrome DevTools MCP and its browser dependencies via the `INSTALL_CHROME_DEVTOOLS_MCP` environment variable.

#### Scenario: Chrome DevTools MCP installation enabled
- **WHEN** `INSTALL_CHROME_DEVTOOLS_MCP=1` is set during base image build
- **THEN** the following SHALL be installed:
  - `chrome-devtools-mcp@latest` npm package (globally)
  - Puppeteer's bundled Chrome browser
- **AND** the following environment variables SHALL be set:
  - `PUPPETEER_CACHE_DIR=/opt/puppeteer-cache`
  - `CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS=1`
- **AND** the browser cache directory SHALL be readable by the `agent` user

#### Scenario: Chrome DevTools MCP installation disabled (default)
- **WHEN** `INSTALL_CHROME_DEVTOOLS_MCP` is not set or set to `0`
- **THEN** no Chrome DevTools MCP dependencies SHALL be installed
- **AND** the base image size SHALL remain unchanged

### Requirement: Playwright MCP Support
The base image build system SHALL support optional installation of Playwright MCP and its browser dependencies via the `INSTALL_PLAYWRIGHT_MCP` environment variable.

#### Scenario: Playwright MCP installation enabled
- **WHEN** `INSTALL_PLAYWRIGHT_MCP=1` is set during base image build
- **THEN** the following SHALL be installed:
  - `@playwright/mcp@latest` npm package (globally)
  - Playwright's Chromium browser
  - Playwright's Chromium system dependencies
- **AND** the following environment variable SHALL be set:
  - `PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers`
- **AND** the browser directory SHALL be readable by the `agent` user

#### Scenario: Playwright MCP installation disabled (default)
- **WHEN** `INSTALL_PLAYWRIGHT_MCP` is not set or set to `0`
- **THEN** no Playwright MCP dependencies SHALL be installed
- **AND** the base image size SHALL remain unchanged
