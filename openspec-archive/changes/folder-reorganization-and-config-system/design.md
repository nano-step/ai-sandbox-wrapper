# Design: Folder Reorganization and Config System

## Context

The AI Sandbox Wrapper provides Docker-based isolation for AI coding tools. Currently, data for tools is stored in `~/.ai-sandbox/` with the following structure:
- `home/<tool>/` - Tool home directories mounted into containers
- `cache/<tool>/` - Tool cache directories
- `cache/git/ssh/` - Cached SSH keys for git access (shared)
- `git-keys/<hash>` - Per-workspace SSH key selections
- Config scattered across: `config.json`, `workspaces`, `git-allowed`, `env`

This organic growth creates confusion about where data lives and makes configuration management difficult. The existing migration code in `ai-run` already handles moving from older dotfile locations - this change extends that pattern.

## Goals / Non-Goals

**Goals:**
- Reorganize folder structure so all tool data lives under `~/.ai-sandbox/tools/<tool>/`
- Consolidate all configuration into a single `~/.ai-sandbox/config.json`
- Provide CLI commands for managing configuration without editing files
- Maintain backward compatibility via automatic migration
- Keep the existing security model intact (opt-in workspaces, git access)

**Non-Goals:**
- Changing the Docker image structure or container internals
- Modifying how tools themselves store data inside their home directories
- Adding new security features (this is purely organizational)
- Supporting Windows natively (WSL2 remains the supported path)

## Decisions

### 1. Folder Structure Layout

**Decision**: Use `tools/<tool>/` as the top-level organization for tool data.

**Alternatives Considered**:
- Flat structure (`~/.ai-sandbox/<tool>/`) - Simpler but could conflict with future config/shared folders
- Nested by category (`cache/<tool>/`, `home/<tool>/`) - Current approach, mixes concerns

**Rationale**: `tools/` namespace provides clear separation and room for growth (e.g., `plugins/`, `logs/`).

**New Structure**:
```
~/.ai-sandbox/
├── config.json           # Unified configuration
├── env                   # API keys (optional separate file for security)
├── shared/
│   └── git/
│       ├── ssh/          # Cached SSH keys/config (shared across tools)
│       └── keys/         # Per-workspace key selections (renamed from git-keys/)
└── tools/
    └── <tool>/
        ├── home/         # Mounted as /home/agent in container
        └── cache/        # Mounted as /home/agent/.cache in container
```

### 2. Unified Configuration Schema

**Decision**: Single JSON file with versioned schema and clear sections.

**Schema**:
```json
{
  "version": 2,
  "workspaces": [
    "/path/to/workspace1",
    "/path/to/workspace2"
  ],
  "git": {
    "allowedWorkspaces": ["/path/to/workspace1"],
    "keySelections": {
      "<md5-hash>": ["key1", "key2"]
    }
  },
  "networks": {
    "global": [],
    "workspaces": {
      "/path/to/workspace1": ["network1", "network2"]
    }
  }
}
```

**Alternatives Considered**:
- YAML config - More human-readable but adds dependency
- TOML config - Good for complex configs but overkill here
- Keep separate files - Current approach, fragmented

**Rationale**: JSON is already used for existing `config.json`, `jq` is commonly available for parsing, and Node.js can read it natively for CLI commands.

### 3. API Keys Handling

**Decision**: Keep `env` as a separate file, but allow optional `env` section in config.json.

**Rationale**: Security-sensitive data should remain in a dedicated file with strict permissions (600). Users who prefer a single config file can use the `env` section, but the separate file takes precedence.

### 4. CLI Command Structure

**Decision**: Add commands to existing CLI entry point (`bin/cli.js`).

**Commands**:
```bash
# Interactive TUI (default)
npx @kokorolx/ai-sandbox-wrapper update

# Scripting-friendly subcommands
npx @kokorolx/ai-sandbox-wrapper config show
npx @kokorolx/ai-sandbox-wrapper workspace add <path>
npx @kokorolx/ai-sandbox-wrapper workspace remove <path>
npx @kokorolx/ai-sandbox-wrapper git enable [--workspace <path>]
npx @kokorolx/ai-sandbox-wrapper git disable [--workspace <path>]
npx @kokorolx/ai-sandbox-wrapper network add <name> [--workspace <path>|--global]
npx @kokorolx/ai-sandbox-wrapper network remove <name> [--workspace <path>|--global]
```

**Alternatives Considered**:
- Separate `ai-config` script - Adds complexity
- Only TUI, no CLI subcommands - Bad for scripting/CI
- Modify `setup.sh` - That's for initial setup only

**Rationale**: Reusing `bin/cli.js` keeps the package surface minimal. TUI provides discoverability, subcommands enable automation.

### 5. Migration Strategy

**Decision**: Extend existing migration function in `ai-run` to handle new structure.

**Migration Steps** (on first run):
1. Check for migration marker (`~/.ai-sandbox/.migrated-v2`)
2. Move `home/<tool>/` → `tools/<tool>/home/`
3. Move `cache/<tool>/` → `tools/<tool>/cache/`
4. Move `cache/git/` → `shared/git/`
5. Move `git-keys/` → `shared/git/keys/`
6. Convert legacy files to unified config:
   - Read `workspaces` file → `config.json.workspaces[]`
   - Read `git-allowed` file → `config.json.git.allowedWorkspaces[]`
   - Preserve existing `config.json.networks`
7. Create marker file with timestamp

**Alternatives Considered**:
- Separate migration script - Users might not run it
- No migration (manual) - Bad UX for existing users
- Keep old paths working indefinitely - Creates confusion

**Rationale**: Auto-migration on first run is the existing pattern and proven to work. Marker file prevents repeated migrations.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Migration corrupts existing data | Create backup before migration, validate destination directories exist before moving |
| Users with custom scripts break | Document new paths clearly, add deprecation warnings to old path access |
| jq not available on all systems | Keep fallback grep-based parsing for critical paths (already exists for network config) |
| Large config.json file | Config is small (typically < 10KB), not a concern |
| Permissions issues during migration | Copy files first, verify success, then delete originals |

## Open Questions

1. **env file format**: Should we support `.env` format (KEY=value) in addition to current bash sourceable format?
2. **Tool-specific config override**: How should `tools/<tool>/config.json` merge with global `config.json`? (Proposed: deep merge, tool-specific wins)
3. **Backward compatibility duration**: How long should we support the old `workspaces`/`git-allowed` files before removing migration code? (Proposed: 6 months / 3 major versions)
