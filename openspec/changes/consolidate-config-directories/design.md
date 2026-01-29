## Context

AI Sandbox Wrapper currently creates 7+ directories/files in the user's home folder:

| Current Path | Purpose |
|--------------|---------|
| `~/.ai-cache/` | Tool-specific cache |
| `~/.ai-home/` | Tool configs |
| `~/.ai-sandbox/` | Network config |
| `~/.ai-workspaces` | Whitelisted directories |
| `~/.ai-env` | API keys |
| `~/.ai-git-allowed` | Git-enabled workspaces |
| `~/.ai-git-keys-*` | SSH key selections |

This clutters the home directory. The goal is to consolidate everything under `~/.ai-sandbox/`.

## Goals / Non-Goals

**Goals:**
- Consolidate all AI Sandbox files under `~/.ai-sandbox/`
- Provide automatic migration for existing users
- Maintain backward compatibility during transition period
- Update all scripts to use new paths

**Non-Goals:**
- Changing the internal structure of tool caches/configs
- Modifying how Docker volumes are mounted (paths inside container stay the same)
- Supporting both old and new paths permanently (migration is one-time)

## Decisions

### Decision 1: New Directory Structure

**Choice:** Flat structure under `~/.ai-sandbox/`

```
~/.ai-sandbox/
├── cache/           # Tool caches (was ~/.ai-cache/)
├── home/            # Tool configs (was ~/.ai-home/)
├── config.json      # Network config (already here)
├── workspaces       # Whitelisted dirs (was ~/.ai-workspaces)
├── env              # API keys (was ~/.ai-env)
├── git-allowed      # Git workspaces (was ~/.ai-git-allowed)
└── git-keys/        # SSH selections (was ~/.ai-git-keys-*)
```

**Rationale:**
- Simple, predictable structure
- Easy to backup (`cp -r ~/.ai-sandbox ~/backup/`)
- Follows conventions of other tools (`~/.docker/`, `~/.npm/`)

**Alternatives considered:**
- Nested structure (e.g., `~/.ai-sandbox/git/allowed`): More complex, no real benefit
- Keep some files at root: Defeats the purpose of consolidation

### Decision 2: Migration Strategy

**Choice:** Automatic migration on first run with backup.

**Migration flow:**
1. On startup, check if old paths exist AND new paths don't
2. If migration needed:
   - Create `~/.ai-sandbox/` structure
   - Move files (not copy) to preserve disk space
   - Create `.migrated` marker file with timestamp
3. If both old and new exist: Warn user, prefer new paths
4. If only new exists: Normal operation

**Rationale:**
- Seamless experience for users
- No manual intervention required
- Marker file prevents re-migration

**Alternatives considered:**
- Manual migration script: Extra step for users, likely forgotten
- Copy instead of move: Wastes disk space, confusing dual state
- No migration (breaking): Poor user experience

### Decision 3: Backward Compatibility Period

**Choice:** No backward compatibility - clean break with migration.

**Rationale:**
- Simpler codebase (single path logic)
- Migration handles existing users
- Old paths become invalid immediately after migration

**Alternatives considered:**
- Check both paths: Complex, error-prone, technical debt
- Symlinks from old to new: Clutters home directory, defeats purpose

### Decision 4: Migration Location

**Choice:** Migration logic in `bin/ai-run` (runs on every tool invocation).

**Rationale:**
- Guaranteed to run before any tool needs the paths
- Single point of migration
- Works for both `ai-run` and `npx` users

**Alternatives considered:**
- In setup.sh: Only runs on initial setup, misses existing users
- Separate migration script: Extra step, easily forgotten
- In each install script: Duplicated logic

### Decision 5: Clean Command Update

**Choice:** Update `bin/cli.js` to use new paths, simplify structure.

**New menu structure:**
```
🧹 AI Sandbox Cleanup

What would you like to clean?
  1. Tool caches (cache/) - Safe to delete
  2. Tool configs (home/) - Loses settings
  3. Config files - Loses preferences
  4. Everything (full reset)
```

**Rationale:**
- Simpler paths to display
- Same functionality, cleaner presentation

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Migration fails mid-way | Atomic operations where possible; marker file tracks completion |
| User has custom scripts using old paths | Document breaking change clearly in release notes |
| Disk full during migration | Move (not copy) to avoid doubling space usage |
| Permission issues on move | Catch errors, provide clear message, suggest manual fix |
| Docker volume mounts break | Container paths unchanged; only host paths change |

## Migration Plan

### Phase 1: Implementation
1. Add migration logic to `bin/ai-run`
2. Update all path references in scripts
3. Update `clean` command
4. Update documentation

### Phase 2: Release
1. Bump to version 2.0.0 (breaking change)
2. Document migration in CHANGELOG
3. Add migration notes to README

### Rollback Strategy
If migration causes issues:
1. User can manually move files back to old locations
2. Downgrade to previous version
3. Old paths will work with old version

## Open Questions

None - design is straightforward.
