## ADDED Requirements

### Requirement: Shared cache directory structure
The system SHALL maintain a shared cache directory at `~/.ai-sandbox/cache/` with subdirectories for each package manager (`npm/`, `bun/`, `pip/`, `playwright-browsers/`). The directories SHALL be created automatically by `ai-run` before container launch if they do not exist.

#### Scenario: First run creates cache directories
- **WHEN** user runs `ai-run opencode` for the first time
- **AND** `~/.ai-sandbox/cache/` does not exist
- **THEN** `ai-run` SHALL create `~/.ai-sandbox/cache/npm/`, `~/.ai-sandbox/cache/bun/`, `~/.ai-sandbox/cache/pip/`, and `~/.ai-sandbox/cache/playwright-browsers/`
- **AND** the container SHALL start successfully with the shared caches mounted

#### Scenario: Cache directories already exist
- **WHEN** user runs `ai-run opencode`
- **AND** `~/.ai-sandbox/cache/` already exists with contents
- **THEN** `ai-run` SHALL reuse the existing cache directories without modification

### Requirement: Shared npm cache mount
The system SHALL mount `~/.ai-sandbox/cache/npm/` to `/home/agent/.npm` inside every container, regardless of which tool is running.

#### Scenario: npm cache shared between tools
- **WHEN** user runs `ai-run opencode` and the agent installs a package via `npm install express`
- **AND** user later runs `ai-run claude` and the agent installs the same package
- **THEN** the second install SHALL use the cached tarball from the shared npm cache
- **AND** no duplicate download SHALL occur

#### Scenario: npm cache shared between sessions
- **WHEN** user runs `ai-run opencode`, the agent installs packages, and the container exits
- **AND** user runs `ai-run opencode` again
- **THEN** the npm cache from the previous session SHALL be available

### Requirement: Shared bun cache mount
The system SHALL mount `~/.ai-sandbox/cache/bun/` to `/home/agent/.bun/install/cache` inside every container.

#### Scenario: bun cache shared between sessions
- **WHEN** user runs `ai-run gemini` and the agent runs `bun add some-package`
- **AND** user later runs `ai-run codex` and the agent runs `bun add some-package`
- **THEN** the second install SHALL use the cached package from the shared bun cache

### Requirement: Shared pip cache mount
The system SHALL mount `~/.ai-sandbox/cache/pip/` to `/home/agent/.cache/pip` inside every container.

#### Scenario: pip cache shared between sessions
- **WHEN** user runs `ai-run aider` and pip downloads packages
- **AND** user later runs `ai-run aider` in a new session
- **THEN** pip SHALL use the cached downloads from the previous session

### Requirement: Shared Playwright browser cache
The system SHALL mount `~/.ai-sandbox/cache/playwright-browsers/` to `/opt/playwright-browsers` inside every container. On first use, the system SHALL seed the shared cache from the image's build-time browsers.

#### Scenario: Playwright browsers seeded on first run
- **WHEN** user runs `ai-run opencode` for the first time after building the image
- **AND** `~/.ai-sandbox/cache/playwright-browsers/` is empty
- **THEN** the system SHALL copy the build-time browsers from the image into the shared cache
- **AND** the Playwright MCP SHALL be able to launch the browser

#### Scenario: Runtime browser update persists
- **WHEN** the agent runs `npx playwright install` inside a container to update browsers
- **AND** the container exits
- **THEN** the updated browsers SHALL be available in the next `ai-run` session

#### Scenario: Playwright browsers shared across tools
- **WHEN** user runs `ai-run opencode` with Playwright MCP
- **AND** user later runs `ai-run claude` with Playwright MCP
- **THEN** both sessions SHALL use the same browser binaries from the shared cache

### Requirement: Cache mount precedence
Shared cache mounts SHALL overlay the per-tool home directory mount. The per-tool home directory SHALL continue to own all non-cache paths (`.config/`, `.local/`, `.gitconfig`, etc.).

#### Scenario: Cache mount overlays home mount
- **WHEN** `ai-run` mounts both `-v "$HOME_DIR":/home/agent` and `-v "$CACHE_DIR/npm":/home/agent/.npm`
- **THEN** `/home/agent/.npm` inside the container SHALL point to the shared cache
- **AND** `/home/agent/.config` SHALL point to the per-tool home directory

### Requirement: Cache cleanup command
The system SHALL provide a way to clear shared caches via the CLI.

#### Scenario: Clean all caches
- **WHEN** user runs `npx @kokorolx/ai-sandbox-wrapper clean cache`
- **THEN** the system SHALL remove contents of `~/.ai-sandbox/cache/npm/`, `~/.ai-sandbox/cache/bun/`, `~/.ai-sandbox/cache/pip/`, and `~/.ai-sandbox/cache/playwright-browsers/`
- **AND** the system SHALL display the amount of disk space freed

#### Scenario: Clean specific cache
- **WHEN** user runs `npx @kokorolx/ai-sandbox-wrapper clean cache npm`
- **THEN** only `~/.ai-sandbox/cache/npm/` SHALL be cleared

### Requirement: Security constraints for shared caches
Shared cache directories SHALL contain only downloaded package tarballs and browser binaries. No credentials, tokens, or authentication data SHALL be stored in or read from the shared cache directories.

#### Scenario: Cache contains no secrets
- **WHEN** inspecting `~/.ai-sandbox/cache/` contents
- **THEN** no files SHALL contain API keys, SSH keys, tokens, or passwords
- **AND** all files SHALL be package manager cache artifacts (tarballs, metadata, browser binaries)
