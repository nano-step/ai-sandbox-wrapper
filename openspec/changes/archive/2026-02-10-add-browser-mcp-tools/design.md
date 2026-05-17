## Context

The AI sandbox wrapper provides Docker-based isolation for AI coding agents. The base image (`ai-base`) already supports optional installation of:
- Playwright (E2E testing framework) via `INSTALL_PLAYWRIGHT=1`
- Ruby/Rails via `INSTALL_RUBY=1`
- OpenSpec CLI, UIPro CLI, and other tools

MCP (Model Context Protocol) is the standard for AI agents to interact with external tools. Browser MCP servers allow AI agents to:
- Navigate and interact with web pages
- Inspect console logs and network requests
- Analyze performance metrics
- Take screenshots and snapshots

Two official MCP servers exist for browser automation:
1. **Chrome DevTools MCP** (Google) - Deep DevTools integration, performance profiling
2. **Playwright MCP** (Microsoft) - Multi-browser support, code generation

Both need to be installed inside the container where the MCP client (OpenCode, Claude, etc.) runs.

## Goals / Non-Goals

**Goals:**
- Add Chrome DevTools MCP as an optional installation in base image
- Add Playwright MCP as an optional installation in base image
- Follow existing patterns for optional tool installation (`INSTALL_*` flags)
- Add user-friendly selection UI in `setup.sh` under "MCP Tools" section
- Configure both tools for secure, headless container operation
- Disable telemetry by default for privacy

**Non-Goals:**
- Sharing browser installations between Chrome DevTools MCP and Playwright MCP (each has its own)
- Modifying `bin/ai-run` for special handling (tools auto-detect container environment)
- Pre-configuring MCP in OpenCode config (user responsibility)
- Supporting headed/GUI mode (container is headless-only)
- Firefox/WebKit support for Playwright MCP (Chromium only to minimize image size)

## Decisions

### Decision 1: Separate Browser Installations

**Choice**: Each MCP tool installs its own browser independently.

**Rationale**:
- Chrome DevTools MCP requires Puppeteer's Chrome (specific version compatibility)
- Playwright MCP requires Playwright's Chromium (different binary)
- Attempting to share would require complex configuration and version management
- Disk space is acceptable trade-off for reliability

**Alternatives Considered**:
- Share Playwright's Chromium via `--executablePath` → Rejected: Version mismatches cause issues
- Single "browser tools" option installing both → Rejected: Users may want only one

### Decision 2: Installation Location

**Choice**: Install browsers in `/opt/` directories with global read access.

```
/opt/puppeteer-cache/     # Chrome DevTools MCP (Puppeteer's Chrome)
/opt/playwright-browsers/ # Playwright MCP (Playwright's Chromium)
```

**Rationale**:
- `/opt/` is standard for optional software
- Global location allows non-root `agent` user to access
- Avoids conflicts with user home directory mounts

### Decision 3: Container Runtime Configuration

**Choice**: Both tools auto-configure for container environment. No `ai-run` changes needed.

**Rationale**:
- Puppeteer detects container and adds `--disable-dev-shm-usage` automatically
- Both tools support `--no-sandbox` flag for non-root operation
- `--headless` is explicit in MCP config (user controls this)

**Container Flags Applied**:
| Flag | Purpose | Applied By |
|------|---------|------------|
| `--no-sandbox` | Non-root user in container | User MCP config |
| `--disable-dev-shm-usage` | Avoid /dev/shm size issues | Puppeteer auto |
| `--headless` | No display server | User MCP config |
| `--disable-gpu` | No GPU in container | Browser auto |

### Decision 4: Telemetry Handling

**Choice**: Disable Chrome DevTools MCP telemetry by default via environment variable.

```dockerfile
ENV CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS=1
```

**Rationale**:
- Sandbox is privacy-focused
- Users may not expect data leaving container
- Playwright MCP has no telemetry

### Decision 5: setup.sh UI Placement

**Choice**: Add new "MCP Tools" section after existing optional tools (Playwright testing, Ruby).

**Rationale**:
- Logical grouping of AI agent capabilities
- Separate from E2E testing tools (different purpose)
- Clear descriptions help users understand the difference

## Risks / Trade-offs

### Risk 1: Large Image Size
**Risk**: Each browser adds 300-400MB to image size.
**Mitigation**: Both are optional. Clear size warnings in setup.sh UI. Users only install what they need.

### Risk 2: Browser Version Drift
**Risk**: npm packages may update browser versions, causing compatibility issues.
**Mitigation**: Use `@latest` tags for MCP packages. Both projects are actively maintained by Google/Microsoft.

### Risk 3: /dev/shm Exhaustion
**Risk**: Chrome may crash if /dev/shm is too small (Docker default: 64MB).
**Mitigation**: Puppeteer auto-uses `--disable-dev-shm-usage`. No action needed.

### Risk 4: User Configuration Complexity
**Risk**: Users must manually configure MCP in OpenCode after installation.
**Mitigation**: Document example configurations in setup output and README.

## Implementation Approach

### File Changes

1. **`lib/install-base.sh`**
   - Add `INSTALL_CHROME_DEVTOOLS_MCP` block (similar to `INSTALL_PLAYWRIGHT`)
   - Add `INSTALL_PLAYWRIGHT_MCP` block
   - Each block adds Dockerfile instructions to `ADDITIONAL_TOOLS_INSTALL`

2. **`setup.sh`**
   - Add "MCP Tools" section with two checkboxes
   - Display tool descriptions and size warnings
   - Set environment variables for install-base.sh

### Dockerfile Generation Pattern

```bash
# Chrome DevTools MCP
if [[ "${INSTALL_CHROME_DEVTOOLS_MCP:-0}" -eq 1 ]]; then
  ADDITIONAL_TOOLS_INSTALL+='ENV PUPPETEER_CACHE_DIR=/opt/puppeteer-cache
ENV CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS=1
RUN mkdir -p /opt/puppeteer-cache && \
    npm install -g chrome-devtools-mcp@latest && \
    npx puppeteer browsers install chrome && \
    chmod -R 755 /opt/puppeteer-cache
'
fi

# Playwright MCP
if [[ "${INSTALL_PLAYWRIGHT_MCP:-0}" -eq 1 ]]; then
  ADDITIONAL_TOOLS_INSTALL+='ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers
RUN mkdir -p /opt/playwright-browsers && \
    npm install -g @playwright/mcp@latest && \
    npx playwright-core install --no-shell chromium && \
    npx playwright-core install-deps chromium && \
    chmod -R 755 /opt/playwright-browsers
'
fi
```

### User MCP Configuration (Documentation)

After installation, users add to `~/.config/opencode/opencode.json`:

```json
{
  "mcp": {
    "chrome-devtools": {
      "type": "local",
      "command": ["chrome-devtools-mcp", "--headless", "--isolated"]
    },
    "playwright": {
      "type": "local",
      "command": ["npx", "@playwright/mcp@latest", "--headless", "--browser", "chromium", "--no-sandbox"]
    }
  }
}
```
