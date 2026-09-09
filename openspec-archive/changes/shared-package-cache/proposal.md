## Why

Each `ai-run` session mounts a per-tool home directory (`~/.ai-sandbox/tools/{tool}/home/` → `/home/agent`). When multiple tools — or multiple sessions of the same tool — install the same npm/bun/pip packages (MCPs via `npx`, Playwright browsers at runtime, Python tools), each session downloads and stores its own copy. For OpenCode specifically, anonymous volumes actively destroy the npm/bun caches on every run (line 2126 of `ai-run`). This wastes disk space and slows down container startup for packages that are already on the host.

## What Changes

- **Shared cache directory on host**: Create `~/.ai-sandbox/cache/{npm,bun,pip}/` as a single cache location shared across all tools and sessions.
- **Mount shared caches into every container**: `ai-run` mounts the shared cache dirs to the standard cache paths inside the container (`/home/agent/.npm`, `/home/agent/.bun/install/cache`, `/home/agent/.cache/pip`), regardless of which tool is running.
- **Remove anonymous volume overrides for OpenCode**: The `CACHE_MOUNTS` block that creates ephemeral anonymous volumes over `.npm`, `.cache`, and `.opencode/node_modules` is removed. The shared cache mount replaces it.
- **Playwright browser cache sharing**: If the agent installs or updates Playwright browsers at runtime (`npx playwright install`), the browser binaries land in a shared location (`~/.ai-sandbox/cache/playwright-browsers/`) mounted to `PLAYWRIGHT_BROWSERS_PATH`, so they persist and are reused across sessions.

## Capabilities

### New Capabilities
- `shared-package-cache`: Shared host-side cache directories for npm, bun, pip, and Playwright browsers, mounted into every container to deduplicate downloads and persist across sessions.

### Modified Capabilities
- `container-runtime`: `ai-run` volume mount logic changes — adds shared cache mounts, removes OpenCode-specific anonymous volume overrides.

## Impact

- **`bin/ai-run`**: Cache mount logic changes (~10 lines). Anonymous volume block removed. New shared cache mounts added before `docker run`.
- **`setup.sh`**: May need to create `~/.ai-sandbox/cache/` subdirectories during initial setup.
- **Security**: Cache dirs contain only downloaded package tarballs — no credentials, no SSH keys, no API tokens. Read/write by the `agent` user inside the container. No new attack surface.
- **Cross-platform**: Docker named volumes and bind mounts work identically on macOS, Linux, and WSL2. No platform-specific concerns.
- **Disk savings**: Depends on usage, but typical MCP installations (Playwright MCP, Chrome DevTools MCP) are 50-200MB each. Sharing eliminates N-1 copies where N is the number of tools/sessions that install them.
