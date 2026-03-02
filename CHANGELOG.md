# Changelog

All notable changes to this project will be documented in this file.

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
