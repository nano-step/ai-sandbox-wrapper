# Tasks: Add Browser MCP Tools

## 1. Install Script Changes

- [x] 1.1 Add Chrome DevTools MCP installation block to `lib/install-base.sh`
- [x] 1.2 Add Playwright MCP installation block to `lib/install-base.sh`
- [x] 1.3 Validate shell syntax with `bash -n lib/install-base.sh`

## 2. Setup UI Changes

- [x] 2.1 Add MCP Tools section header to `setup.sh`
- [x] 2.2 Add Chrome DevTools MCP selection prompt with description
- [x] 2.3 Add Playwright MCP selection prompt with description
- [x] 2.4 Wire up environment variables to install-base.sh call
- [x] 2.5 Validate shell syntax with `bash -n setup.sh`

## 3. Testing

- [x] 3.1 Test base image build with `INSTALL_CHROME_DEVTOOLS_MCP=1`
- [x] 3.2 Verify `chrome-devtools-mcp --help` works in container
- [x] 3.3 Test base image build with `INSTALL_PLAYWRIGHT_MCP=1`
- [x] 3.4 Verify `npx @playwright/mcp --help` works in container
- [x] 3.5 Test both tools installed together

## 4. Documentation

- [x] 4.1 Update README with MCP tools section
- [x] 4.2 Add example OpenCode MCP configuration
