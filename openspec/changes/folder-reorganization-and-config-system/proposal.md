# Folder Reorganization and Config System

## Why

The current `~/.ai-sandbox/` folder structure has grown organically and lacks clear organization. Configuration is scattered across multiple files (`config.json`, `env`, `workspaces`, `git-allowed`), making it hard to manage and extend. The `home/` and `cache/` directories mix data from all tools at the same level, creating potential conflicts. Additionally, there's no way to manage configuration through the CLI - users must manually edit files.

This change consolidates the folder structure around a tool-centric layout and introduces a unified configuration system with CLI management via `npx @kokorolx/ai-sandbox-wrapper update`.

## What Changes

### Folder Structure Reorganization
- **NEW**: `~/.ai-sandbox/tools/<tool>/` becomes the root for all tool-specific data
  - `home/` - Mounted as `/home/agent` in container (was `~/.ai-sandbox/home/<tool>`)
  - `cache/` - Mounted as `/home/agent/.cache` (was `~/.ai-sandbox/cache/<tool>`)
  - `config.json` - Tool-specific configuration overrides (optional)
- **NEW**: `~/.ai-sandbox/shared/git/` for shared Git/SSH configuration across all tools
- **MODIFIED**: Git cache moves from `~/.ai-sandbox/cache/git/` to `~/.ai-sandbox/shared/git/`
- **DEPRECATED**: Old paths (`home/`, `cache/` at root level) will be auto-migrated

### Configuration Consolidation
- **NEW**: Unified `~/.ai-sandbox/config.json` with structured sections:
  - `workspaces` - List of allowed directories (was separate `workspaces` file)
  - `git` - Git access settings per workspace (was separate `git-allowed` file)
  - `networks` - Network access settings (global + per workspace, already partially exists)
- **BREAKING**: Separate config files (`workspaces`, `git-allowed`, `env`) deprecated in favor of unified config
- **NEW**: `env` section in config.json for API keys (with optional separate file for security)

### CLI Config Management
- **NEW**: `npx @kokorolx/ai-sandbox-wrapper update` command with interactive TUI
- **NEW**: Subcommands for scripting:
  - `update workspace add/remove <path>`
  - `update git enable/disable [workspace]`
  - `update network add/remove <network> [workspace|global]`
- **NEW**: `npx @kokorolx/ai-sandbox-wrapper config show` to display current configuration

## Capabilities

### New Capabilities
- `sandbox-folder-structure`: Defines the canonical `~/.ai-sandbox/` directory layout with tool-centric organization
- `unified-config`: Consolidated JSON configuration with workspaces, git, and network settings
- `config-cli`: Interactive TUI and CLI commands for managing sandbox configuration

### Modified Capabilities
- `container-runtime`: Update `bin/ai-run` to use new folder paths and read from unified config

## Impact

### Code Changes
- `bin/ai-run` - Major refactor for new paths and config reading
- `bin/cli.js` - Add `update` and `config` commands
- `setup.sh` - Generate new config format, migration from old files
- `lib/generate-ai-run.sh` - Update path constants

### Breaking Changes
- Old folder structure auto-migrates on first run (extends existing migration in `ai-run`)
- Users with custom scripts referencing old paths need to update
- `~/.ai-sandbox/workspaces` file deprecated (reads config.json instead)
- `~/.ai-sandbox/git-allowed` file deprecated (reads config.json instead)

### Dependencies
- `jq` recommended but not required (fallback parsing exists)
- No new npm dependencies expected (TUI uses existing `tput`-based menus)
