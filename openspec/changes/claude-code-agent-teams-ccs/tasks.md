# Tasks: Claude Code Agent Teams and CCS Integration

## 1. Claude Dockerfile Changes

- [x] 1.1 Add tmux installation to `lib/install-claude.sh` Dockerfile (apt-get install -y tmux, as root before USER agent)
- [x] 1.2 Add CCS installation to `lib/install-claude.sh` Dockerfile (npm install -g @kaitranntt/ccs, as root)
- [x] 1.3 Update feature list in install script output message to mention Agent Teams and CCS
- [x] 1.4 Validate shell syntax with `bash -n lib/install-claude.sh`

## 2. Container Runtime Changes

- [x] 2.1 Add `mount_tool_config "$HOME/.ccs" ".ccs"` to Claude case in `bin/ai-run` (after existing `.claude` mount at line 591)
- [x] 2.2 Validate shell syntax with `bash -n bin/ai-run`

## 3. Testing

- [ ] 3.1 Rebuild Claude Docker image with `bash lib/install-claude.sh` (manual: requires Docker)
- [ ] 3.2 Verify tmux is available: `ai-run claude --shell` then `tmux -V` (manual: requires Docker)
- [ ] 3.3 Verify CCS is available: `ai-run claude --shell` then `ccs --version` (manual: requires Docker)
- [ ] 3.4 Verify CCS config persistence: configure a provider, restart container, verify config preserved (manual: requires Docker)
- [ ] 3.5 Verify Agent Teams env var passes through: add `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` to `~/.ai-sandbox/env`, run `ai-run claude --shell`, check `echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` (manual: requires Docker)
- [ ] 3.6 Verify Claude Code version is 2.1.32+: `ai-run claude --shell` then `claude --version` (manual: requires Docker)

## 4. Documentation

- [x] 4.1 Update TOOLS.md Claude section with Agent Teams setup instructions
- [x] 4.2 Update TOOLS.md Claude section with CCS usage instructions
- [x] 4.3 Document required environment variables in TOOLS.md (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS, CLAUDE_CODE_TEAMMATE_MODE, OPENROUTER_API_KEY, etc.)
- [x] 4.4 Document OAuth provider limitations for headless Docker in TOOLS.md
- [x] 4.5 Run full test suite: `npm test`
