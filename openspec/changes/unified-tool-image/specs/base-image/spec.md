## MODIFIED Requirements

### Requirement: Chrome DevTools MCP Support
The base image build system SHALL support optional installation of Chrome DevTools MCP and its browser dependencies via the `INSTALL_CHROME_DEVTOOLS_MCP` environment variable. When building the unified image, these enhancements SHALL be composed into the same Dockerfile alongside tool snippets.

#### Scenario: Chrome DevTools MCP installation enabled
- **WHEN** `INSTALL_CHROME_DEVTOOLS_MCP=1` is set during unified image build
- **THEN** the following SHALL be installed in the unified image:
  - `chrome-devtools-mcp@latest` npm package (globally)
  - Shared Chromium browser via Playwright
- **AND** the following environment variables SHALL be set:
  - `CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS=1`
- **AND** the browser cache directory SHALL be readable by the `agent` user

#### Scenario: Chrome DevTools MCP installation disabled (default)
- **WHEN** `INSTALL_CHROME_DEVTOOLS_MCP` is not set or set to `0`
- **THEN** no Chrome DevTools MCP dependencies SHALL be installed
- **AND** the unified image size SHALL not include Chrome DevTools overhead

### Requirement: Playwright MCP Support
The base image build system SHALL support optional installation of Playwright MCP and its browser dependencies via the `INSTALL_PLAYWRIGHT_MCP` environment variable. When building the unified image, these enhancements SHALL be composed into the same Dockerfile alongside tool snippets.

#### Scenario: Playwright MCP installation enabled
- **WHEN** `INSTALL_PLAYWRIGHT_MCP=1` is set during unified image build
- **THEN** the following SHALL be installed in the unified image:
  - `@playwright/mcp@latest` npm package (globally)
  - Playwright's Chromium browser
  - Playwright's Chromium system dependencies
- **AND** the following environment variable SHALL be set:
  - `PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers`
- **AND** the browser directory SHALL be readable by the `agent` user

#### Scenario: Playwright MCP installation disabled (default)
- **WHEN** `INSTALL_PLAYWRIGHT_MCP` is not set or set to `0`
- **THEN** no Playwright MCP dependencies SHALL be installed
- **AND** the unified image size SHALL not include Playwright overhead

## ADDED Requirements

### Requirement: Base image serves as foundation for unified build
The base image build logic SHALL be usable as the foundation layer of the unified Dockerfile, composable with tool snippets appended after it.

#### Scenario: Base preamble generation
- **WHEN** `build-sandbox.sh` requests the base image Dockerfile content
- **THEN** `install-base.sh` SHALL output the base Dockerfile lines (package installs, user setup, enhancement tools) without the final `USER agent` and closing lines
- **AND** tool snippets SHALL be appended between the base content and the final user setup

#### Scenario: Enhancement flags passed through
- **WHEN** `INSTALL_RTK=1`, `INSTALL_PLAYWRIGHT_MCP=1`, or other enhancement flags are set
- **THEN** the base section of the unified Dockerfile SHALL include those enhancements
- **AND** the behavior SHALL be identical to the current `install-base.sh` flag handling
