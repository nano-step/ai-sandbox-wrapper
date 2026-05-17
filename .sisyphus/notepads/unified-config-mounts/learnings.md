## Learnings

## 2026-03-06 Initial Context
- `mount_tool_config()` function at line 606-619 of ai-run is reusable — takes host_path and container_path (relative to /home/agent)
- The case statement to replace is lines 622-688
- HOME_DIR logic to replace is lines 578-583
- SANDBOX_DIR is resolved earlier in the script, AI_SANDBOX_CONFIG is the config.json path
- `jq` is used elsewhere in the script (line 567-568) for tool validation, so it's available
- OpenCode bundled skills copy logic (lines 632-644) must be preserved as a separate block
- cli.js `runConfigTool()` at line 323-383 uses `path.join(SANDBOX_DIR, 'tools', toolName, 'home')` — needs update to `path.join(SANDBOX_DIR, 'home')`

## 2026-03-06 Tasks 1.1-1.5, 2.1-2.2 Implementation
- Implemented TOOL_CONFIGS associative array with all 15 tools at lines 595-612
- Added get_installed_tools() function at lines 615-626 with jq fallback to all known tools
- Replaced case block with loop at lines 647-652
- OpenCode skills copy block preserved at lines 654-669, gated on `get_installed_tools | grep -qw "opencode"`
- HOME_DIR simplified to `$SANDBOX_DIR/home` at line 579 (removed per-tool branching)
- bash -n validation passed

## 2026-03-06 Tasks 3.1-3.4 Implementation
- Added `migrate_to_unified_home()` function at lines 588-637
- Function checks for `.migrated-unified-home` marker file first (skip if exists)
- Iterates `$SANDBOX_DIR/tools/*/home/` directories
- Uses `cp -rn` (no-clobber) as primary method — works on macOS and Linux
- Falls back to `rsync -a --ignore-existing` if cp -rn fails
- Displays progress: "🔄 Migrating tools/{tool}/home/ → home/"
- Shows completion message with count of migrated directories
- Suggests cleanup: "ℹ️  Old per-tool home directories preserved. Run 'npx @kokorolx/ai-sandbox-wrapper clean' to remove them."
- Creates marker file with timestamp after successful migration
- bash -n validation passed
