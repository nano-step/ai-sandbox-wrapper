## Context

`ai-run` mounts a per-tool home directory from the host (`~/.ai-sandbox/tools/{tool}/home/`) as `/home/agent` inside the container. Package manager caches (npm, bun, pip) live under this home directory, so each tool maintains its own isolated cache. For OpenCode, anonymous Docker volumes are mounted over `.npm`, `.cache`, and `.opencode/node_modules` to prevent host/container Bun/Node conflicts — making those caches fully ephemeral.

When agents install MCPs (`npx @playwright/mcp`), download packages, or run `npm install` in a project, the downloaded tarballs go into these per-tool or ephemeral caches. The same package installed across 3 tools = 3 copies on disk.

Playwright browsers are baked into the image at `/opt/playwright-browsers/` (build-time). If an agent runs `npx playwright install` at runtime to update, the new browsers go to the ephemeral container filesystem and are lost on exit.

## Goals / Non-Goals

**Goals:**
- Single shared cache directory on host for npm, bun, and pip package downloads
- All `ai-run` sessions (any tool) read/write the same cache
- Runtime-installed Playwright browsers persist across sessions
- Remove the OpenCode anonymous volume workaround
- Zero user configuration — works out of the box after `setup.sh`

**Non-Goals:**
- Sharing `node_modules/` directories between projects (those are project-specific, not cache)
- Persisting globally installed npm packages (`npm install -g`) across sessions — only download caches
- Changing the per-tool home directory structure for configs (`.config/opencode`, `.claude`, etc.)
- Deduplicating packages across npm and bun caches (they use different formats)

## Decisions

### 1. Host-side cache directory structure

**Decision**: `~/.ai-sandbox/cache/` with subdirectories per package manager.

```
~/.ai-sandbox/cache/
├── npm/                  → mounted to /home/agent/.npm
├── bun/                  → mounted to /home/agent/.bun/install/cache
├── pip/                  → mounted to /home/agent/.cache/pip
└── playwright-browsers/  → mounted to /opt/playwright-browsers
```

**Why not Docker named volumes?** Bind mounts are visible on the host filesystem — users can inspect, clean, or back them up. Named volumes are opaque and harder to manage. The rest of `ai-run` already uses bind mounts for everything.

### 2. Mount order and precedence

**Decision**: Shared cache mounts are added **after** the home directory mount (`-v "$HOME_DIR":/home/agent`) but **before** tool-specific config mounts. Docker processes `-v` flags left-to-right; later mounts overlay earlier ones at the same path.

```bash
-v "$HOME_DIR":/home/agent              # base home (per-tool)
-v "$CACHE_DIR/npm":/home/agent/.npm    # shared cache overlays per-tool .npm
-v "$CACHE_DIR/bun":/home/agent/.bun/install/cache  # shared bun cache
-v "$CACHE_DIR/pip":/home/agent/.cache/pip           # shared pip cache
```

This means the per-tool home still owns `.config/`, `.local/`, `.gitconfig`, etc. Only the cache subdirectories are shared.

**Why overlay instead of symlinking inside the home dir?** Symlinks inside a bind-mounted directory pointing to another bind-mounted directory are fragile across Docker for Mac/Linux differences. Direct mount overlay is the standard Docker pattern and works identically everywhere.

### 3. Playwright browser sharing

**Decision**: Mount `~/.ai-sandbox/cache/playwright-browsers/` to `/opt/playwright-browsers` (the `PLAYWRIGHT_BROWSERS_PATH` set in the base image). On first run, the build-time browsers are not visible (mount shadows the image layer), so we seed the cache from the image.

**Seeding strategy**: During `setup.sh` or first `ai-run`, if `~/.ai-sandbox/cache/playwright-browsers/` is empty, run a one-time copy from the image:
```bash
docker run --rm -v "$CACHE_DIR/playwright-browsers":/export ai-sandbox:latest \
  cp -a /opt/playwright-browsers/. /export/
```

After seeding, all sessions share the same browser binaries. Runtime `npx playwright install` updates land in the shared cache and persist.

**Alternative considered**: Not mounting over `/opt/playwright-browsers/` and relying on the image layer. Rejected because runtime browser updates would be lost, and the image would need rebuilding to update browsers.

### 4. Removing OpenCode anonymous volume workaround

**Decision**: Remove the `CACHE_MOUNTS` block entirely (lines 2120-2127 of `ai-run`).

```bash
# REMOVE THIS:
if [[ "$TOOL" == "opencode" ]]; then
  CACHE_MOUNTS="-v /home/agent/.npm -v /home/agent/.cache -v /home/agent/.opencode/node_modules"
fi
```

The original purpose was to prevent host-side npm/bun cache from conflicting with the container's Node/Bun versions. With shared caches mounted as overlays, the container always writes to the shared cache (correct Node/Bun version), and the per-tool home's `.npm`/`.cache` dirs are shadowed — achieving the same isolation without anonymous volumes.

For `.opencode/node_modules` specifically: this is OpenCode's internal dependency directory, not a cache. It should persist in the per-tool home (already does via the home mount). The anonymous volume was overly aggressive.

### 5. Cache directory creation

**Decision**: `ai-run` creates cache directories on first use (not `setup.sh`). This avoids requiring users to re-run setup.

```bash
CACHE_DIR="$SANDBOX_DIR/cache"
mkdir -p "$CACHE_DIR/npm" "$CACHE_DIR/bun" "$CACHE_DIR/pip" "$CACHE_DIR/playwright-browsers"
```

Added early in `ai-run`, right after `SANDBOX_DIR` is resolved.

## Risks / Trade-offs

**[Cache corruption from concurrent writes]** → Low risk. npm and bun caches use content-addressable storage (files named by hash). Two containers writing the same package simultaneously produce identical files. pip uses lock files for cache writes. No mitigation needed beyond what the package managers already do.

**[Playwright browser version mismatch]** → If the shared cache has browsers from a different Playwright version than what's in the image, Playwright may re-download. This is the correct behavior — Playwright handles version management internally. The cache just avoids re-downloading when versions match.

**[Disk usage visibility]** → Users may not realize `~/.ai-sandbox/cache/` is growing. Mitigation: add `npx @kokorolx/ai-sandbox-wrapper clean cache` command (or extend existing `clean` command) to clear shared caches.

**[Breaking change for existing users]** → No. Existing per-tool home directories are untouched. The shared cache mounts overlay on top. If a user downgrades `ai-run`, the overlay mounts simply don't happen and behavior reverts to per-tool caches.

**[Shadowing build-time Playwright browsers]** → Mounting over `/opt/playwright-browsers/` hides the image-layer browsers. Mitigated by the seeding step. If seeding is skipped, the agent sees an empty browser dir and `npx playwright install` re-downloads — slower first run but self-healing.
