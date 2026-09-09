## 1. Shared cache directory setup in `ai-run`

- [x] 1.1 Add `CACHE_DIR="$SANDBOX_DIR/cache"` variable definition after `SANDBOX_DIR` is resolved in `bin/ai-run`
- [x] 1.2 Add `mkdir -p "$CACHE_DIR/npm" "$CACHE_DIR/bun" "$CACHE_DIR/pip" "$CACHE_DIR/playwright-browsers"` before the `docker run` command
- [x] 1.3 Validate `bin/ai-run` with `bash -n bin/ai-run`

## 2. Shared cache volume mounts in `ai-run`

- [x] 2.1 Add shared cache mount variables after the home dir mount setup: `-v "$CACHE_DIR/npm":/home/agent/.npm:delegated`, `-v "$CACHE_DIR/bun":/home/agent/.bun/install/cache:delegated`, `-v "$CACHE_DIR/pip":/home/agent/.cache/pip:delegated`
- [x] 2.2 Add Playwright browser cache mount: `-v "$CACHE_DIR/playwright-browsers":/opt/playwright-browsers:delegated`
- [x] 2.3 Insert the shared cache mounts into the `docker run` command, after `$TOOL_CONFIG_MOUNTS` and before `$CACHE_MOUNTS`
- [x] 2.4 Validate `bin/ai-run` with `bash -n bin/ai-run`

## 3. Remove OpenCode anonymous volume workaround

- [x] 3.1 Remove the `CACHE_MOUNTS` block (lines ~2120-2127) that creates anonymous volumes for `.npm`, `.cache`, and `.opencode/node_modules` when `TOOL == "opencode"`
- [x] 3.2 Remove `$CACHE_MOUNTS` from the `docker run` command arguments
- [x] 3.3 Validate `bin/ai-run` with `bash -n bin/ai-run`

## 4. Playwright browser cache seeding

- [x] 4.1 Add a seeding check in `ai-run`: if `$CACHE_DIR/playwright-browsers/` is empty and the image contains `/opt/playwright-browsers/`, run a one-time `docker run --rm -v "$CACHE_DIR/playwright-browsers":/export "$IMAGE" cp -a /opt/playwright-browsers/. /export/` to populate the shared cache
- [x] 4.2 Add a flag file (`$CACHE_DIR/playwright-browsers/.seeded`) to skip the check on subsequent runs
- [x] 4.3 Validate `bin/ai-run` with `bash -n bin/ai-run`

## 5. Cache cleanup CLI command

- [x] 5.1 Add `clean cache [type]` subcommand to `bin/cli.js` that removes contents of `~/.ai-sandbox/cache/` (all or specific: `npm`, `bun`, `pip`, `playwright-browsers`)
- [x] 5.2 Display disk space freed after cleanup (use `du -sh` before deletion)
- [x] 5.3 Validate `bin/cli.js` with `node --check bin/cli.js`

## 6. Testing & Validation

- [x] 6.1 Run `bash -n bin/ai-run` and `node --check bin/cli.js` to validate syntax
- [ ] 6.2 Build unified image and run `ai-run opencode`, install a package via `npm install express` in a temp dir, verify `~/.ai-sandbox/cache/npm/` is populated on host
- [ ] 6.3 Run `ai-run claude`, install the same package, verify no re-download (cache hit)
- [ ] 6.4 Run `ai-run opencode`, verify `npx @playwright/mcp` uses shared cache and Playwright browser launches
- [ ] 6.5 Run `npx @kokorolx/ai-sandbox-wrapper clean cache` and verify caches are cleared
- [x] 6.6 Run `npm test` to verify existing test suite passes
