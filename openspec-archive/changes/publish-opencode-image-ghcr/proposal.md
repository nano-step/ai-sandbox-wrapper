## Why

Users currently must build the `ai-opencode` Docker image locally before they can use the sandbox. The build takes 10-20 minutes, requires Docker + Rust toolchain on the host, and produces inconsistent results across architectures (amd64 vs arm64) and OS versions. The existing GitHub Actions workflow (`ci.yml`) builds images but discards them, while the GitLab CI publishes a different image shape (unified multi-tool) that doesn't match the per-tool `ai-opencode` model the codebase actually uses. Publishing reproducible images to GitHub Container Registry (ghcr.io) eliminates local build pain, gives users a 30-second `docker pull` experience, and aligns the publish pipeline with the npm package publish already running on GitHub Actions.

## What Changes

- **NEW**: Two preset definitions (`ci/presets/base.env`, `ci/presets/full.env`) that lock the set of `INSTALL_*` flags shipped in each published image variant.
- **NEW**: Reusable GitHub Actions workflow (`.github/workflows/build-image.yml`) that takes `tool` + `preset` inputs, builds the image (base layer + tool layer), and pushes to ghcr.io with versioned tags.
- **NEW**: Caller workflow (`.github/workflows/build-opencode.yml`) that invokes the reusable workflow for the `opencode` tool against both presets (`base`, `full`) on push to `master` (when relevant files change) and on `workflow_dispatch`.
- **MODIFIED**: `bin/ai-run` registry default switches from `registry.gitlab.com/kokorolee/ai-sandbox-wrapper/ai-sandbox:latest` to `ghcr.io/nano-step/ai-opencode:base` when `AI_IMAGE_SOURCE=registry`, with new `AI_IMAGE_REGISTRY` and `AI_IMAGE_TAG` env vars to allow override.
- **MODIFIED**: `.github/workflows/ci.yml` removes the `build-base`, `build-base-addons`, and `build-tools` jobs (they build-and-discard); keeps the `lint` job. The new `build-opencode.yml` replaces them.
- **POLICY** (already documented in `AGENTS.md`): When a new `INSTALL_*` flag is added, the contributor MUST ask the user which preset(s) should include it, then edit `ci/presets/{base,full}.env` accordingly. No auto-inclusion.

## Capabilities

### New Capabilities
- `ci-published-images`: Defines what published images exist (`ai-opencode:base`, `ai-opencode:full`), what each contains (preset flag set), how they are tagged and pulled, and the policy for adding new contents.

### Modified Capabilities
- `base-image`: Adds the `INSTALL_PLAYWRIGHT_HOST`, `INSTALL_ACLI`, `INSTALL_PUP`, and `INSTALL_GO` requirements that are currently implemented in `install-base.sh` but undocumented in the spec.

## Impact

**Affected code**:
- `.github/workflows/ci.yml` — remove build-and-discard jobs
- `.github/workflows/build-image.yml` — new reusable workflow
- `.github/workflows/build-opencode.yml` — new caller workflow
- `ci/presets/base.env` — new preset definition
- `ci/presets/full.env` — new preset definition
- `bin/ai-run` — change default registry from GitLab to ghcr.io; add `AI_IMAGE_REGISTRY` env var
- `README.md` — document `docker pull` UX for ghcr.io images
- `AGENTS.md` — already updated (preset policy for future flag additions)

**Affected systems**:
- GitHub Container Registry (`ghcr.io/nano-step/ai-opencode`) — new packages
- GitHub Actions minutes — adds ~15-20min per relevant push (mitigated by `changes:` filter + cache)

**Backward compatibility**:
- The GitLab CI (`.gitlab-ci.yml`) is left untouched for users who pull from GitLab; the registry switch in `bin/ai-run` is a default change. Users with `AI_IMAGE_SOURCE=registry` set will start pulling from ghcr.io on next run; they can pin back to GitLab with `AI_IMAGE_REGISTRY=registry.gitlab.com/kokorolee/...`.

**Out of scope** (deferred to future changes):
- Multi-arch builds (`linux/arm64`) — start with `linux/amd64` only.
- Cosign image signing — defer to a follow-up security change.
- Removing or rewriting `.gitlab-ci.yml` — keep as-is for now.
- Building other tool images (`ai-claude`, `ai-amp`, etc.) on CI — the reusable workflow makes this trivial later, but only `opencode` is in scope for this change.
