# Changelog

All notable changes to this project will be documented in this file.

## [3.4.2] - 2026-05-11

### Added
- **`rebuild` command** — `npx @kokorolx/ai-sandbox-wrapper rebuild` rebuilds the Docker image using
  the existing `~/.ai-sandbox/config.json` without going through the interactive setup menu.
  Reads `tools.installed` and `mcp.installed` from config and maps them to the correct `INSTALL_*`
  flags automatically. Supports `--no-cache` to bypass Docker layer cache.

### Fixed
- **`setup.sh` ignores `INSTALL_*` env vars** — Previously `setup.sh` hardcoded all `INSTALL_*`
  flags to `0` at the start of the build block, silently discarding any env vars passed by the
  caller (e.g. `INSTALL_CHROME_DEVTOOLS_MCP=1 npx ... setup`). Now uses `${VAR:-0}` so
  caller-supplied values are respected.

## [3.4.1] - 2026-05-11

### Fixed
- **Skip MCP entry registration when binary isn't in the image** — 3.4.0
  always registered both `playwright_port_*` and `chrome-devtools_port_*`
  entries under host-Chrome mode, regardless of which MCP binaries were
  actually installed in the container image. When OpenCode tried to spawn
  a missing binary the MCP server would fail. `bin/ai-run` now consults
  `$AI_SANDBOX_CONFIG` (`mcp.installed`) and only registers the entries
  whose binaries are listed. `pmcp::register_host_chrome` now treats an
  empty key as "skip this one".

## [3.4.0] - 2026-05-11

### Added
- **Chrome DevTools MCP host-Chrome support** — `chrome-devtools-mcp`
  can now drive the same visible host Chrome that Playwright MCP
  uses. Each container gets a paired `chrome-devtools_port_<port>`
  entry alongside `playwright_port_<port>`, both pointing at the same
  CDP endpoint. Chrome DevTools MCP connects via `--browserUrl`.
- **`CHROME_DEVTOOLS_MCP_NAME`** env var passed into the container so
  the agent knows its own entry (mirrors `PLAYWRIGHT_MCP_NAME`).
- `pmcp::sweep_dead` and `pmcp::register` helpers (prefix-aware,
  reusable across MCP server types).
- `pmcp::register_host_chrome` registers both entries atomically under
  one lock.

### Changed
- `configure_opencode_mcp` now skips the static `chrome-devtools`
  entry under host-Chrome mode (same treatment as `playwright`).
- AGENTS.md documents both env vars.

### Notes
- Both MCP servers share one Chrome process. Two CDP clients on one
  Chrome works correctly — they create separate browser contexts.
- The existing token-cost optimization TODO (`docs/TODO-playwright-mcp.md`)
  now applies to both prefixes; same solution covers both.

## [3.3.0] - 2026-05-11

Stable release of the multi-container Playwright MCP work. Combines
3.3.0-beta.0 (per-container entries + locked sweep+append) with
3.3.0-beta.2 (symlink-resolution fix).

### Known follow-ups (tracked in `docs/TODO-playwright-mcp.md`)
- Each container currently sees *all* `playwright_port_*` entries in
  the shared config, inflating agent context with unused tool
  definitions. Per-container effective config + cleanup-on-exit
  planned.

---

## [3.3.0-beta.2] - 2026-05-11

## [3.3.0-beta.1] - 2026-05-11

### Fixed
- **`bin/ai-run` symlink resolution** — Resolving `SCRIPT_DIR` from `$BASH_SOURCE[0]` returned the invocation path (typically `~/bin/ai-run`), not the symlink target where the package actually lives. As a result, `lib/playwright-mcp-config.sh` could not be sourced from npm-installed copies, the helper functions were undefined, and the entire host-Chrome / per-container MCP block was silently skipped — leaving containers with no `PLAYWRIGHT_MCP_NAME` env var and no `playwright_port_*` registration. Now walks the symlink chain with a portable loop (macOS-compatible, no `readlink -f`).

## [3.3.0-beta.0] - 2026-05-09

### Fixed
- **Multi-container Playwright MCP race** — Previously, when host Chrome (CDP) mode was active, every container booting `bin/ai-run` would overwrite the single `mcp.playwright` entry in the shared `~/.config/opencode/opencode.json`, so concurrent containers would clobber each other's CDP endpoint and end up driving the wrong Chrome.

### Changed
- **Per-container MCP entry** — Each container now registers its own `playwright_port_<port>` entry in the shared OpenCode config (append-only, never overwritten). Containers learn their own entry name via `PLAYWRIGHT_MCP_NAME` env var; `AGENTS.md` documents the convention.
- **Locked sweep + append** — All config mutations happen inside an exclusive lock (`flock` on Linux, atomic `mkdir` mutex on macOS). Stale `playwright_port_*` entries whose ports no longer respond to a CDP probe are removed on every container start.
- **Reuse-if-alive Chrome** — `bin/ai-run` now reuses an existing Chrome on the container's deterministic port instead of failing or launching a duplicate.
- **`configure_opencode_mcp`** — No longer writes a static `playwright` entry under host-Chrome mode; the per-container entry handles that case.

### Added
- `lib/playwright-mcp-config.sh` — helper library: `pmcp::sanitize_name`, `pmcp::probe_chrome`, `pmcp::sweep_and_append`, `pmcp::with_lock` (portable lock).
- `tests/playwright-mcp/sweep-append.sh` — five-test shell suite covering name sanitization, CDP probing, sweep+append correctness, lock contention, and the portable-lock primitive.

## [3.0.8] - 2026-03-23

### Changed
- **nano-brain mount: full read-write access** — Changed `~/.nano-brain` container mount from read-only (with selective rw overlays on `logs/` and `memory/`) to fully writable (`:delegated`). This allows the container to modify `config.yml`, write to all subdirectories, and run `npx nano-brain write` without requiring the daemon.

## [2.7.1] - 2026-03-02

### Fixed
- **RTK Skills in Container**: RTK OpenCode skills (`rtk`, `rtk-setup`) are now actually copied into the container's OpenCode config directory (`~/.config/opencode/skills/`) during base image build. Previously the skills were bundled in the npm package but not installed into the Docker image, so OpenCode agents inside containers couldn't auto-discover them.


## [2.7.0] - 2026-02-25

### Added
- **Git Fetch-Only Mode**: New `--git-fetch` flag and interactive menu options (4 & 5) allow git fetch/pull while blocking push operations. Uses git's `pushInsteadOf` mechanism — no Docker image changes needed.
  - `ai-run opencode --git-fetch` — force fetch-only for this session
  - Interactive prompt now offers "Fetch only" options alongside full access
  - Saved per-workspace via `git.fetchOnlyWorkspaces` in config.json
  - CLI: `npx @kokorolx/ai-sandbox-wrapper git fetch-only <path>` / `git full <path>`
- **Bundled Skills**: OpenCode containers now auto-install default skills on first run (won't override existing).
  - `rtk` — Token optimizer skill (command reference for RTK binary)
  - `rtk-setup` — Persistent RTK enforcement across sessions and subagents

### Fixed
- Fixed `setup-ssh-config` crash during git credential setup when no SSH Host entries match selected keys (pre-existing bug, now handled gracefully with fallback)

## [2.2.0] - 2026-02-04

### Added
- **OSC 52 Clipboard Support**: Added a fallback clipboard mechanism for macOS and SSH users. Now `pbcopy` inside the container correctly copies text to the host clipboard using ANSI escape sequences.
- **Screenshot Directory Detection**: `ai-run` now automatically detects the macOS screenshot save location (via `defaults read com.apple.screencapture location`) and prompts the user to whitelist it if missing. This enables seamless drag-and-drop of screenshots into AI tools.

### Fixed
- Fixed "air-gapped" clipboard issues on macOS hosts where X11/Wayland sockets are unavailable.
- Resolved permission errors when dragging files from custom screenshot directories (e.g., `~/Screenshots`) that weren't explicitly whitelisted.

## [2.1.1] - 2026-01-28

### Fixed
- Minor bug fixes for cache isolation.

## [2.1.0] - 2026-01-25

### Added
- **Native Persistence**: Tool configurations now bind-mount directly from host `~/.config` directories.
- **Cache Isolation**: Heavy caches (`node_modules`, `.npm`) are now isolated in anonymous volumes to prevent host pollution.
- **Node 22 LTS**: Upgraded base image runtime for better stability.

## [2.0.0] - 2026-01-15

### Changed
- **Config Reorganization**: Migrated to `~/.ai-sandbox` structure with unified `config.json`.
- **Tool-Centric Layout**: Reorganized internal directory structure.
