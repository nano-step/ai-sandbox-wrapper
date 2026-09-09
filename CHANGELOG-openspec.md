# OpenSpec Integration Changelog

## Summary
Added support for additional productivity tools (spec-kit, ux-ui-promax, openspec, playwright) to the AI Sandbox Wrapper. All tools are installed **inside Docker containers only** (no host installation), making them available to all containerized AI tools.

## Timeline

### 2026-01-27 - Session: Playwright + TypeScript Support

**Changes:**
- Added `playwright` as optional additional tool in setup menu
- Added TypeScript + typescript-language-server to base image (always installed)
- Fixed pnpm global bin issue by using npm for Playwright installation

**Files Modified:**
- `setup.sh`: Added `playwright` to ADDITIONAL_TOOL_OPTIONS menu
- `lib/install-base.sh`: 
  - Added TypeScript/LSP installation (always)
  - Added Playwright conditional block with system dependencies
- `README.md`: Added "Additional Tools" documentation section

**Playwright Dependencies (installed when selected):**
- System libs: libglib2.0-0, libnspr4, libnss3, libdbus-1-3, libatk1.0-0, libatk-bridge2.0-0, libcups2, libxcb1, libxkbcommon0, libatspi2.0-0, libx11-6, libxcomposite1, libxdamage1, libxext6, libxfixes3, libxrandr2, libgbm1, libcairo2, libpango-1.0-0, libasound2
- Playwright + browsers via npm

**TypeScript/LSP (always installed):**
- `typescript` - TypeScript compiler (tsc)
- `typescript-language-server` - LSP for AI coding assistants

### 2026-01-23 - Session 1: Initial OpenSpec Support
**Commit:** `ea7c1ca` - feat: add OpenSpec as optional additional tool in base image

- Added OpenSpec as an optional tool to install inside Docker containers
- Modified `lib/install-base.sh` to conditionally install OpenSpec
- Created mechanism to pass `INSTALL_OPENSPEC` environment variable
- Fixed scoped package name: `@fission-ai/openspec`

### 2026-01-23 - Session 1: Standalone Option (Later Reverted)
**Commit:** `3c63ad7` - feat: add OpenSpec as standalone tool option

- Created `lib/install-openspec.sh` for host installation
- Added OpenSpec to main AI tools menu
- Introduced dual installation modes: standalone and container
- **LATER REMOVED** - User clarified all additional tools should be container-only

### 2026-01-23 - Session 1: Menu Reorganization
**Commit:** `c5c637c` - refactor: move spec-kit, ux-ui-promax, openspec to Additional Tools menu

- Moved spec-kit, ux-ui-promax, and openspec from main AI tools menu
- Created separate "Additional Tools" menu for productivity tools
- Separated main AI tools (containerized + IDE) from additional tools

### 2026-01-23 - Session 1: Container-Only Refactor
**Commit:** `8d1d267` - refactor: make all additional tools container-only

**Key realization:** User clarified ALL additional tools should be container-only.

Changes:
- **Deleted** standalone installer scripts:
  - `lib/install-openspec.sh`
  - `lib/install-spec-kit.sh`
  - `lib/install-ux-ui-promax.sh`
- **Removed** `openspec-container` option (now just `openspec`)
- **Updated** `lib/install-base.sh` to install all three tools in base image
- **Removed** host aliases for additional tools
- Additional tools menu now only shown if containerized tools selected

### 2026-01-25 - Session 2: Spec-Kit Installation Fix
**Commit:** `eeae651` - fix: use correct spec-kit installation from GitHub

**Critical discovery:** User pointed out spec-kit is NOT from npm, it's from GitHub.

Fixed:
```bash
# WRONG (npm):
RUN npm install -g @letuscode/spec-kit

# CORRECT (pipx from GitHub):
RUN pipx install specify-cli --pip-args="git+https://github.com/github/spec-kit.git"
```

- spec-kit is a **Python CLI tool** installed via `pipx`
- Command name is `specify` (not `speckit`)
- Source: `github/spec-kit` GitHub repository

**Commit:** `b1a065c` - chore: regenerate base Dockerfile with correct spec-kit installation
- Regenerated Dockerfile with the correct installation command

**Commit:** `000ab70` - fix: use correct 'specify' command name for spec-kit
- Updated completion message in `setup.sh` to use `specify` instead of `speckit`

**Commit:** `5c6cfc2` - chore: make install-base.sh executable
- Fixed file permissions for `lib/install-base.sh`

**Commit:** `811e371` - fix: use bun instead of npm for uipro-cli installation
- Changed from `npm install -g` to `bun install -g` for uipro-cli
- Base image uses Bun runtime, not npm
- Ensures consistent package manager usage

## Final State

### Architecture
All three additional tools are installed **in the base Docker image** (`ai-base:latest`), making them available in ALL containerized AI tools without requiring separate installations.

### Installation Methods
| Tool | Method | Package/Source | Command |
|------|--------|----------------|---------|
| **spec-kit** | pipx (Python) | `git+https://github.com/github/spec-kit.git` | `specify` |
| **ux-ui-promax** | bun | `uipro-cli` | `uipro` |
| **openspec** | bun (local) | `@fission-ai/openspec` | `openspec` |
| **playwright** | npm | `playwright` | `npx playwright` |
| **typescript** | npm (always) | `typescript`, `typescript-language-server` | `tsc`, `typescript-language-server` |

### Files Modified
1. **`setup.sh`**:
   - Main AI tools menu unchanged
   - Additional Tools menu (shown only if containerized tools selected)
   - Exports: `INSTALL_SPEC_KIT`, `INSTALL_UX_UI_PROMAX`, `INSTALL_OPENSPEC`

2. **`lib/install-base.sh`**:
   - Builds base Docker image with conditional tool installation
   - Generates `dockerfiles/base/Dockerfile` with correct RUN commands

3. **`dockerfiles/base/Dockerfile`**:
   - Generated file (recreated during setup)
   - Contains installation commands for all three tools

### Verification Status
✅ All package names verified:
- `@fission-ai/openspec` - Confirmed from npm registry
- `uipro-cli` - Confirmed from npm registry
- `github/spec-kit` - Confirmed from GitHub, installed via pipx

✅ All command names verified:
- `specify` - Correct for spec-kit
- `uipro` - Correct for ux-ui-promax
- `openspec` - Correct for openspec

## Testing Checklist

When testing the complete flow:

```bash
# 1. Run setup
./setup.sh

# 2. Select a containerized AI tool (e.g., claude, gemini)

# 3. Select all three additional tools:
#    - spec-kit
#    - ux-ui-promax
#    - openspec

# 4. After setup completes, verify installations:
docker run --rm ai-base:latest specify --version
docker run --rm ai-base:latest uipro --version
docker run --rm ai-base:latest openspec --version

# 5. Verify tools are available in AI containers:
ai-run claude
# Inside container:
which specify uipro openspec
```

## Key Technical Decisions

1. **Container-only installation** - No host pollution, all tools inside containers
2. **Base image installation** - All containerized AI tools inherit these tools
3. **Conditional installation** - Tools only installed if user selects them during setup
4. **Correct installation methods**:
   - Python tools (spec-kit) → pipx from GitHub
   - npm tools (ux-ui-promax) → npm global
   - Bun tools (openspec) → Local install with symlink

## Documentation Updates Needed

- [ ] Update README.md with additional tools section
- [ ] Add usage examples for each tool
- [ ] Document that tools are only available inside containers
- [ ] Add troubleshooting section for tool installation issues

## Known Issues / Limitations

1. **No host access**: Additional tools only available inside AI containers, not on host
2. **Base image rebuild**: Changing tool selection requires rebuilding base image
3. **All or nothing**: Can't select different tools for different AI containers (all inherit from base)

## Future Improvements

1. Consider per-tool Docker layers for faster rebuilds
2. Add option to install tools on host (optional)
3. Create unified config management for all three tools
4. Add integration tests for tool availability in containers

### 2026-09-09 - Session: publish-ai-base-image-ghcr

**Changes:**
- Published ai-base Docker image to ghcr.io/nano-step/ai-base with rolling/sha/semver tag scheme per preset (base, full)
- New `lib/ensure-ai-base.sh` helper that pulls ai-base:<preset> from ghcr.io before tool install scripts run
- 14 tool install scripts (claude, codex, aider, amp, auggie, codebuddy, droid, gemini, jules, qoder, qwen, shai, opencode, tool) updated to:
  - Invoke `lib/ensure-ai-base.sh` before docker build
  - Generate Dockerfiles with `FROM ai-base:${BASE_IMAGE_PRESET:-base}` (explicit preset tag, no more :latest)
- `lib/install-base.sh` adds opt-in `BASE_IMAGE_MODE=registry` path that pulls instead of builds (CI parity)
- `setup.sh` exports `BASE_IMAGE_PRESET=base` by default
- `.github/workflows/build-image.yml` adds `Push ai-base to ghcr.io` step between tool build and smoke test (with continue-on-error: true)

**New env vars:**
- `BASE_IMAGE_MODE` (default `local`): switch between local-build and registry-pull behavior
- `BASE_IMAGE_PRESET` (default `base`): which preset image to pull (`base` or `full`)
- `BASE_IMAGE_ALLOW_LOCAL_BUILD` (default `1`): fallback to local build when pull fails
- `AI_IMAGE_BASE_REGISTRY` (default `ghcr.io/nano-step/ai-base`): override registry source
- `AI_IMAGE_BASE_TAG` (default = preset): pin to a specific sha/semver for rollback

**Files Modified:**
- `lib/ensure-ai-base.sh` (new, ~140 lines)
- `lib/install-base.sh` (added registry-mode opt-in)
- `lib/install-{claude,codex,aider,amp,auggie,codebuddy,droid,gemini,jules,qoder,qwen,shai,opencode,tool}.sh` (14 files; helper invocation + FROM line)
- `setup.sh` (export BASE_IMAGE_PRESET)
- `.github/workflows/build-image.yml` (Push ai-base step)
- `README.md` (new `Pull base image from ghcr.io` section)

**Impact:** First tool install on a clean machine drops from ~15 min to ~30 s. Subsequent installs use cached local image. No Rust/Go/Node toolchain required on the host (when network is available).

**Out of scope:** multi-arch builds, cosign signing, SBOM generation, ghcr.io SHA-tag retention cleanup, modifying bin/ai-run, modifying the unified ai-sandbox:latest flow (lib/build-sandbox.sh), kilo (uses node:22-slim not ai-base).

