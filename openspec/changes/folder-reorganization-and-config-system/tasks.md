# Tasks: Folder Reorganization and Config System

## 1. Configuration Schema & Migration

- [x] 1.1 Define config.json v2 schema with workspaces, git, and networks sections
- [x] 1.2 Create config initialization function in `bin/ai-run` to create default config.json
- [x] 1.3 Implement legacy file migration (workspaces, git-allowed → config.json)
- [x] 1.4 Add config version detection and upgrade logic

## 2. Folder Structure Migration

- [x] 2.1 Update migration marker from `.migrated` to `.migrated-v2`
- [x] 2.2 Implement `home/<tool>/` → `tools/<tool>/home/` migration
- [x] 2.3 Implement `cache/<tool>/` → `tools/<tool>/cache/` migration
- [x] 2.4 Implement `cache/git/` → `shared/git/` migration
- [x] 2.5 Implement `git-keys/` → `shared/git/keys/` migration
- [ ] 2.6 Add backup mechanism before migration (copy, not move)
- [ ] 2.7 Add migration success verification before deleting old paths

## 3. Native Tool Config Compatibility

- [ ] 3.1 Verify `copy_tool_config()` copies to new `tools/<tool>/home/` path
- [ ] 3.2 Ensure XDG config paths (`~/.config/<tool>/`) work seamlessly inside container
- [ ] 3.3 Ensure legacy dotfile paths (`~/.<tool>/`) work seamlessly inside container
- [ ] 3.4 Verify tool data persists between sessions
- [ ] 3.5 Test each supported tool finds its config at expected container path

## 4. Update ai-run Script

- [x] 4.1 Update `CACHE_DIR` path to `~/.ai-sandbox/tools/<tool>/cache`
- [x] 4.2 Update `HOME_DIR` path to `~/.ai-sandbox/tools/<tool>/home`
- [x] 4.3 Update `GIT_CACHE_DIR` path to `~/.ai-sandbox/shared/git`
- [x] 4.4 Update saved keys path to `~/.ai-sandbox/shared/git/keys/`
- [ ] 4.5 Replace `read_network_config()` to read from unified config.json
- [x] 4.6 Replace workspace validation to read from config.json.workspaces
- [x] 4.7 Replace git-allowed check to read from config.json.git.allowedWorkspaces
- [x] 4.8 Add fallback to legacy files for backward compatibility

## 5. Update setup.sh Script

- [x] 5.1 Update setup.sh to generate config.json v2 format
- [x] 5.2 Remove generation of legacy `workspaces` file (or generate both temporarily)
- [x] 5.3 Update tool config copy paths to new structure
- [ ] 5.4 Add migration trigger for existing installations

## 6. CLI Config Commands (bin/cli.js)

- [x] 6.1 Add `config show` command to display current configuration
- [x] 6.2 Add `config show --json` flag for machine-readable output
- [x] 6.3 Add config file read/write utility functions

## 7. CLI Workspace Commands

- [x] 7.1 Add `workspace add <path>` command
- [x] 7.2 Add `workspace remove <path>` command
- [x] 7.3 Add `workspace list` command
- [x] 7.4 Implement tilde expansion for paths (`~/projects` → full path)
- [x] 7.5 Add duplicate detection for workspace add

## 8. CLI Git Commands

- [x] 8.1 Add `git enable --workspace <path>` command
- [x] 8.2 Add `git disable --workspace <path>` command
- [x] 8.3 Add `git status` command to show enabled workspaces

## 9. CLI Network Commands

- [x] 9.1 Add `network add <name> --global` command
- [x] 9.2 Add `network add <name> --workspace <path>` command
- [x] 9.3 Add `network remove <name> --global` command
- [x] 9.4 Add `network remove <name> --workspace <path>` command
- [x] 9.5 Add `network list` command

## 10. Interactive TUI (update command)

- [x] 10.1 Create main menu for `npx @kokorolx/ai-sandbox-wrapper update`
- [x] 10.2 Implement "Manage Workspaces" TUI submenu
- [x] 10.3 Implement "Manage Git Access" TUI submenu
- [x] 10.4 Implement "Manage Networks" TUI submenu
- [x] 10.5 Reuse existing multi_select/single_select TUI patterns from setup.sh

## 11. Documentation

- [x] 11.1 Update README.md with new folder structure
- [x] 11.2 Update README.md with CLI commands documentation
- [x] 11.3 Add migration notes for existing users
- [ ] 11.4 Update CONTRIBUTING.md with new paths

## 12. Testing & Verification

- [ ] 12.1 Test migration from clean legacy installation
- [ ] 12.2 Test migration with partial legacy data
- [ ] 12.3 Test all CLI workspace commands
- [ ] 12.4 Test all CLI git commands
- [ ] 12.5 Test all CLI network commands
- [ ] 12.6 Test interactive TUI update menu
- [ ] 12.7 Verify ai-run works with new paths after migration
- [ ] 12.8 Verify native tool configs work seamlessly after migration
