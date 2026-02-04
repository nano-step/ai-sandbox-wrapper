# Changelog

All notable changes to this project will be documented in this file.

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
