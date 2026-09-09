## Why

Currently AI Sandbox Wrapper creates multiple directories in the user's home folder with the `.ai-*` prefix:
- `~/.ai-cache/`
- `~/.ai-home/`
- `~/.ai-sandbox/`
- `~/.ai-workspaces`
- `~/.ai-env`
- `~/.ai-git-allowed`
- `~/.ai-git-keys-*`

This clutters the home directory and makes it harder to manage. Consolidating everything under a single `~/.ai-sandbox/` directory would:
- Reduce home directory clutter
- Make backup/restore easier (single directory)
- Simplify the `clean` command
- Follow the pattern used by other tools (e.g., `~/.docker/`, `~/.npm/`)

## What Changes

- **BREAKING**: Move all `.ai-*` directories/files into `~/.ai-sandbox/`
- New structure:
  ```
  ~/.ai-sandbox/
  ├── cache/           # Was ~/.ai-cache/
  │   ├── claude/
  │   ├── opencode/
  │   └── ...
  ├── home/            # Was ~/.ai-home/
  │   ├── claude/
  │   ├── opencode/
  │   └── ...
  ├── config.json      # Network config (already here)
  ├── workspaces       # Was ~/.ai-workspaces
  ├── env              # Was ~/.ai-env
  ├── git-allowed      # Was ~/.ai-git-allowed
  └── git-keys/        # Was ~/.ai-git-keys-*
      ├── {hash1}
      └── {hash2}
  ```
- Add migration logic to move existing files on first run
- Update all scripts to use new paths
- Update `clean` command to use new structure
- Update documentation

## Capabilities

### New Capabilities
- `config-migration`: Automatic migration from old `.ai-*` paths to new consolidated structure

### Modified Capabilities
- `container-runtime`: Update all path references to use `~/.ai-sandbox/` subdirectories
- `cache-cleanup`: Update clean command to use new consolidated paths and simplified menu

## Impact

- `bin/ai-run`: Update all path references
- `bin/cli.js`: Update clean command paths
- `setup.sh`: Update path references, add migration
- `lib/*.sh`: Update install scripts
- `README.md`: Update directory structure documentation
- **Migration**: Existing users need automatic migration on first run
- **Breaking**: Old paths will no longer work after migration
