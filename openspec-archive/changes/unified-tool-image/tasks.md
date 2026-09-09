## 1. Snippet Extraction — Refactor install scripts

- [x] 1.1 Add `dockerfile_snippet()` function and `SNIPPET_MODE` guard to `lib/install-claude.sh`
- [x] 1.2 Add `dockerfile_snippet()` function and `SNIPPET_MODE` guard to `lib/install-opencode.sh`
- [x] 1.3 Add `dockerfile_snippet()` function and `SNIPPET_MODE` guard to `lib/install-gemini.sh`
- [x] 1.4 Add `dockerfile_snippet()` function and `SNIPPET_MODE` guard to `lib/install-aider.sh`
- [x] 1.5 Add `dockerfile_snippet()` function and `SNIPPET_MODE` guard to remaining install scripts (`install-amp.sh`, `install-codex.sh`, `install-kilo.sh`, `install-qwen.sh`, `install-droid.sh`, `install-qoder.sh`, `install-auggie.sh`, `install-codebuddy.sh`, `install-jules.sh`, `install-shai.sh`, `install-openclaw.sh`)
- [x] 1.6 Validate all refactored scripts with `bash -n lib/install-*.sh`

## 2. Unified Build Script — Create `lib/build-sandbox.sh`

- [x] 2.1 Create `lib/build-sandbox.sh` that accepts a comma-separated tool list and enhancement flags
- [x] 2.2 Implement base Dockerfile preamble generation (reuse `install-base.sh` logic for base layers + enhancement flags)
- [x] 2.3 Implement snippet composition loop: source each tool's `install-{tool}.sh` in `SNIPPET_MODE=1`, call `dockerfile_snippet`, append to Dockerfile
- [x] 2.4 Add final Dockerfile lines: `USER agent`, `CMD ["bash"]` (no ENTRYPOINT)
- [x] 2.5 Generate `dockerfiles/sandbox/Dockerfile` and run `docker build -t ai-sandbox:latest`
- [x] 2.6 Save installed tools list to `~/.ai-sandbox/config.json` under `tools.installed`
- [x] 2.7 Validate `build-sandbox.sh` with `bash -n lib/build-sandbox.sh`

## 3. Setup Flow — Update `setup.sh`

- [x] 3.1 Replace per-tool install loop (`for tool in "${TOOLS[@]}"... install-{tool}.sh`) with single call to `build-sandbox.sh`
- [x] 3.2 Pre-select previously installed tools from `config.json` `tools.installed` in the multi-select menu
- [x] 3.3 Add old image cleanup prompt: detect `ai-{tool}:latest` images and offer `docker rmi`
- [x] 3.4 Add `alias ai="ai-run"` to shell RC alongside per-tool aliases
- [x] 3.5 Update completion message to reflect unified image (show `ai-sandbox:latest` instead of per-tool images)
- [x] 3.6 Validate `setup.sh` with `bash -n setup.sh`

## 4. Runtime — Update `bin/ai-run`

- [x] 4.1 Change image resolution: replace `IMAGE="ai-${TOOL}:latest"` with `IMAGE="ai-sandbox:latest"` (and registry equivalent)
- [x] 4.2 Make tool argument optional: when no tool is provided and TTY is attached, default to shell mode
- [x] 4.3 When tool argument is provided, use `--entrypoint {tool}` to override the container's `CMD ["bash"]`
- [x] 4.4 Add tool validation: read `config.json` `tools.installed`, warn if requested tool is not installed
- [x] 4.5 Update shell mode welcome message to list all installed tools (read from `config.json`)
- [x] 4.6 Handle non-interactive mode without tool argument: show error "No tool specified and no TTY available"
- [x] 4.7 Preserve all existing functionality: `--shell`, `--network`, `--expose`, `--password`, `--git-fetch`, tool-specific config mounts
- [x] 4.8 Validate `bin/ai-run` with `bash -n bin/ai-run`

## 5. CI Pipeline — Update `.gitlab-ci.yml`

- [x] 5.1 Replace per-tool image build jobs with single `ai-sandbox:latest` build job
- [x] 5.2 Add `TOOLS` CI variable (comma-separated) to control which tools are included in the registry image (default: all)
- [x] 5.3 Update registry push to use `ai-sandbox:latest` tag

## 6. Testing & Validation

- [x] 6.1 Run `bash -n` on all modified shell scripts
- [ ] 6.2 Build unified image locally with 2-3 tools and verify tools are accessible inside the container
- [ ] 6.3 Test `ai-run` shell mode (no tool argument) — verify welcome message and tool availability
- [ ] 6.4 Test `ai-run {tool}` direct mode — verify tool launches correctly
- [ ] 6.5 Test `ai-run {tool} --shell` — verify shell mode with tool-specific config mounts
- [ ] 6.6 Test tool validation — run `ai-run` with a tool not in `config.json` and verify warning
- [x] 6.7 Run `npm test` to verify existing test suite passes
