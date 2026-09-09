# Tasks: Consolidate Config Directories

## 1. Migration Logic

- [x] 1.1 Create `migrate_config()` function in `bin/ai-run` to detect and execute migration
- [x] 1.2 Implement migration detection: check if old paths exist AND new paths don't
- [x] 1.3 Implement `~/.ai-cache/` → `~/.ai-sandbox/cache/` migration
- [x] 1.4 Implement `~/.ai-home/` → `~/.ai-sandbox/home/` migration
- [x] 1.5 Implement `~/.ai-workspaces` → `~/.ai-sandbox/workspaces` migration
- [x] 1.6 Implement `~/.ai-env` → `~/.ai-sandbox/env` migration
- [x] 1.7 Implement `~/.ai-git-allowed` → `~/.ai-sandbox/git-allowed` migration
- [x] 1.8 Implement `~/.ai-git-keys-*` → `~/.ai-sandbox/git-keys/` migration (strip prefix)
- [x] 1.9 Create `.migrated` marker file on successful migration
- [x] 1.10 Add error handling for permission/disk issues during migration
- [x] 1.11 Call `migrate_config()` at start of `bin/ai-run` before any path usage

## 2. Update bin/ai-run Paths

- [x] 2.1 Update `WORKSPACES_FILE` to `~/.ai-sandbox/workspaces`
- [x] 2.2 Update `ENV_FILE` to `~/.ai-sandbox/env`
- [x] 2.3 Update `CACHE_DIR` to `~/.ai-sandbox/cache/$TOOL`
- [x] 2.4 Update `HOME_DIR` to `~/.ai-sandbox/home/$TOOL`
- [x] 2.5 Update `AI_SANDBOX_CONFIG` to `~/.ai-sandbox/config.json` (already correct)
- [x] 2.6 Update git-allowed path to `~/.ai-sandbox/git-allowed`
- [x] 2.7 Update git-keys path to `~/.ai-sandbox/git-keys/`
- [x] 2.8 Update all `mkdir -p` commands to create new paths

## 3. Update setup.sh Paths

- [x] 3.1 Update `WORKSPACES_FILE` reference to `~/.ai-sandbox/workspaces`
- [x] 3.2 Update `ENV_FILE` reference to `~/.ai-sandbox/env`
- [x] 3.3 Add migration call or ensure `~/.ai-sandbox/` is created during setup

## 4. Update lib/*.sh Install Scripts

- [x] 4.1 Update `lib/install-*.sh` scripts to use `~/.ai-sandbox/cache/$TOOL`
- [x] 4.2 Update `lib/install-*.sh` scripts to use `~/.ai-sandbox/home/$TOOL`
- [x] 4.3 Update `lib/ssh-key-selector.sh` to use new git-keys path (N/A - no changes needed)

## 5. Update bin/cli.js (Clean Command)

- [x] 5.1 Update `buildCategoryOptions()` labels to use new paths (cache/, home/)
- [x] 5.2 Update `buildToolItems()` to use `~/.ai-sandbox/cache` and `~/.ai-sandbox/home`
- [x] 5.3 Update `buildGlobalItems()` to use paths within `~/.ai-sandbox/`
- [x] 5.4 Update `listGitKeyFiles()` to read from `~/.ai-sandbox/git-keys/`
- [x] 5.5 Add "Everything (full reset)" option to delete entire `~/.ai-sandbox/`
- [x] 5.6 Update display labels to show relative paths (cache/, home/, etc.)

## 6. Update Documentation

- [x] 6.1 Update README.md "Directory Structure" section with new paths
- [x] 6.2 Update README.md "Configuration Files" section
- [x] 6.3 Update README.md cleanup command examples
- [x] 6.4 Update AGENTS.md with new directory structure
- [x] 6.5 Add migration notes to README.md (breaking change warning)

## 7. Testing & Verification

- [x] 7.1 Syntax verification: `bash -n bin/ai-run` passes
- [x] 7.2 Syntax verification: `bash -n setup.sh` passes
- [x] 7.3 Syntax verification: `node --check bin/cli.js` passes
- [ ] 7.4 Manual test: Fresh install creates `~/.ai-sandbox/` structure
- [ ] 7.5 Manual test: Migration moves old paths to new structure
- [ ] 7.6 Manual test: `.migrated` marker prevents re-migration
- [ ] 7.7 Manual test: `clean` command shows new path structure
- [ ] 7.8 Manual test: "Everything" option deletes entire `~/.ai-sandbox/`
- [ ] 7.9 Manual test: Tools run correctly with new paths
