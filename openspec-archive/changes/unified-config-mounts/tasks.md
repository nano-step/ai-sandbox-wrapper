## 1. Config mount registry

- [x] 1.1 Define `TOOL_CONFIGS` associative array in `bin/ai-run` mapping each tool name to its config paths (space-separated relative paths)
- [x] 1.2 Add `get_installed_tools()` function that reads `config.json` `tools.installed` via `jq`, with fallback to all known tools
- [x] 1.3 Replace the tool-gated `case "$TOOL"` config mount block with a loop over `get_installed_tools()` that mounts all configs from the registry
- [x] 1.4 Keep OpenCode bundled skills copy logic as a separate block (runs if opencode is in installed tools, not gated on `$TOOL`)
- [x] 1.5 Validate `bin/ai-run` with `bash -n bin/ai-run`

## 2. Shared home directory

- [x] 2.1 Replace `HOME_DIR` logic: remove per-tool branching (`tools/$TOOL/home` vs `tools/shell/home`), set `HOME_DIR="$SANDBOX_DIR/home"` unconditionally
- [x] 2.2 Validate `bin/ai-run` with `bash -n bin/ai-run`

## 3. Migration from per-tool homes

- [x] 3.1 Add migration function that detects existing `~/.ai-sandbox/tools/*/home/` directories and merges them into `~/.ai-sandbox/home/` using `rsync -a --ignore-existing` (or `cp -rn`)
- [x] 3.2 Add `.migrated-unified-home` marker file to skip migration on subsequent runs
- [x] 3.3 Display migration progress and suggest cleanup of old directories
- [x] 3.4 Validate `bin/ai-run` with `bash -n bin/ai-run`

## 4. CLI updates

- [x] 4.1 Update `config tool` command in `bin/cli.js` to use new home path (`~/.ai-sandbox/home/`) instead of `~/.ai-sandbox/tools/{tool}/home/`
- [x] 4.2 Validate `bin/cli.js` with `node --check bin/cli.js`

## 5. Testing & Validation

- [x] 5.1 Run `bash -n bin/ai-run` and `node --check bin/cli.js` to validate syntax
- [x] 5.2 Run `npm test` to verify existing test suite passes
- [ ] 5.3 Test `ai-run` shell mode — verify all installed tools' configs are mounted
- [ ] 5.4 Test `ai-run opencode` — run `gemini` inside container, verify config saves to `~/.config/gemini/` on host
- [ ] 5.5 Test migration — create fake per-tool home dirs, run `ai-run`, verify merge into `~/.ai-sandbox/home/`
- [ ] 5.6 Test `config tool opencode` CLI command — verify it shows correct paths
