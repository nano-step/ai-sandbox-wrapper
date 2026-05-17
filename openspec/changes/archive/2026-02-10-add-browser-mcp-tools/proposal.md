## Why

AI coding agents (OpenCode, Claude, etc.) running inside the sandbox need browser automation capabilities for web testing, debugging, and performance analysis. Currently, the base image supports Playwright for E2E testing, but lacks MCP (Model Context Protocol) servers that allow AI agents to interactively control browsers. Adding Chrome DevTools MCP and Playwright MCP enables AI agents to navigate websites, inspect console/network, and analyze performance directly from within the sandbox container.

## What Changes

- Add new "MCP Tools" selection section in `setup.sh` for browser automation tools
- Add `INSTALL_CHROME_DEVTOOLS_MCP` flag to `lib/install-base.sh` for Chrome DevTools MCP installation
- Add `INSTALL_PLAYWRIGHT_MCP` flag to `lib/install-base.sh` for Playwright MCP installation
- Chrome DevTools MCP installs: `chrome-devtools-mcp` npm package + Puppeteer's bundled Chrome (~400MB)
- Playwright MCP installs: `@playwright/mcp` npm package + Chromium browser (~300MB)
- Both tools configured for headless container operation with `--no-sandbox` flag
- Chrome DevTools MCP telemetry disabled by default via `CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS=1`

## Capabilities

### New Capabilities
- `browser-mcp-tools`: Optional installation of MCP servers (Chrome DevTools MCP and Playwright MCP) that enable AI agents to control browsers for automation, debugging, and performance analysis within the sandbox container.

### Modified Capabilities
- `base-image`: Adding new optional installation flags (`INSTALL_CHROME_DEVTOOLS_MCP`, `INSTALL_PLAYWRIGHT_MCP`) following the existing pattern for `INSTALL_PLAYWRIGHT` and `INSTALL_RUBY`.

## Impact

- **Files Modified**:
  - `lib/install-base.sh` - Add Chrome DevTools MCP and Playwright MCP installation blocks
  - `setup.sh` - Add MCP Tools selection UI section
  - `dockerfiles/base/Dockerfile` - Generated with new optional dependencies

- **Dependencies Added** (when enabled):
  - `chrome-devtools-mcp@latest` (npm) - Google's official MCP server
  - `@playwright/mcp@latest` (npm) - Microsoft's official MCP server
  - Puppeteer's Chrome browser (for Chrome DevTools MCP)
  - Playwright's Chromium browser (for Playwright MCP)

- **Image Size Impact**:
  - Chrome DevTools MCP: +~400MB (Chrome browser)
  - Playwright MCP: +~300MB (Chromium browser)
  - Both are optional and only installed when selected

- **Runtime Requirements**:
  - Both tools handle container detection automatically (headless, no-sandbox)
  - No changes needed to `bin/ai-run` - Puppeteer auto-uses `--disable-dev-shm-usage`

- **User Configuration** (post-install):
  - Users configure MCP in `~/.config/opencode/opencode.json` to use installed tools
