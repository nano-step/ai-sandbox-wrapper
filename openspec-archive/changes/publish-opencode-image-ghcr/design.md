## Context

The repository has two parallel, half-working CI pipelines:

1. **GitLab CI** (`.gitlab-ci.yml`) builds a unified `ai-sandbox` image (one image containing all selected tools) and pushes it to `registry.gitlab.com/kokorolee/...`. This is referenced by `bin/ai-run` when `AI_IMAGE_SOURCE=registry`.
2. **GitHub Actions CI** (`.github/workflows/ci.yml`) builds per-tool images but only verifies they exist with `docker images | grep` — **never pushes them anywhere**. The build artifacts are discarded.

The npm package publish (`publish-stable.yml`, `publish-beta.yml`) is already on GitHub via a reusable workflow from `nano-step/shared-workflows`. The codebase's image strategy is **per-tool** (`ai-opencode:latest` extends `ai-base:latest`), not unified. The GitHub Actions CI matches this model; the GitLab CI does not. This change consolidates publish onto GitHub (matches existing npm publish location) and aligns the image shape with the actual codebase architecture.

## Goals / Non-Goals

**Goals:**
- Users can `docker pull ghcr.io/nano-step/ai-opencode:base` and have a working sandbox image in ~30 seconds (vs 10-20 minutes local build).
- The set of `INSTALL_*` flags shipped in each preset is **declarative** (defined in `.env` files), versioned, and reviewable in PRs.
- Adding a new `INSTALL_*` flag requires explicit decision about which preset(s) it belongs to (policy in `AGENTS.md`).
- The workflow is **reusable** so building additional tool images (`ai-claude`, `ai-amp`) in the future is a copy-paste of a 10-line caller workflow.
- Image tags support both rolling (`:base`) and immutable (`:base-sha-<short>`, `:base-v<x.y.z>`) consumption patterns.
- Build is fast (~5-10 min for warm cache, ~15-20 min cold) via GitHub Actions buildx + GHA cache.

**Non-Goals:**
- Multi-architecture support (`linux/arm64`). Deferred — adds 2-3x build time via QEMU. Separate change after baseline ships.
- Cosign image signing. Deferred to a security-focused change.
- Replacing or removing `.gitlab-ci.yml`. Kept as-is so existing GitLab pulls continue to work.
- Building images for other AI tools in this repo. The reusable workflow design makes this trivial, but scope is `ai-opencode` only.
- SBOM generation, provenance attestation. Future hardening.

## Decisions

### D1: Registry choice — ghcr.io over GitLab Container Registry

**Decision**: Push to `ghcr.io/nano-step/ai-opencode`.

**Rationale**:
- Repo `origin` is GitHub (`nano-step/ai-sandbox-wrapper`); ghcr.io is the natural pairing.
- `GITHUB_TOKEN` is built-in to the workflow — no extra secret management for the base case.
- Public packages on ghcr.io have **unlimited storage and bandwidth** for public repos; GitLab free tier caps at 5GB/project.
- The existing npm publish workflows already run on GitHub Actions; co-locating the Docker publish reduces context switching.

**Alternatives considered**:
- *GitLab Container Registry*: Already wired up via `.gitlab-ci.yml`. Rejected because the unified-image strategy there doesn't match the per-tool model the codebase uses.
- *Docker Hub*: Free tier has aggressive pull rate limits for anonymous users. Rejected.
- *Both ghcr.io and GitLab in parallel*: 2x maintenance burden, tag drift risk. Rejected for v1.

### D2: Preset definition format — `.env` files, not inline matrix

**Decision**: Each preset is a `ci/presets/<name>.env` file containing `INSTALL_FOO=1` lines. The reusable workflow sources the file via `set -a; source ci/presets/${PRESET}.env; set +a` before invoking `lib/install-base.sh`.

**Rationale**:
- Single source of truth for "what's in `:base`" — readers don't have to chase YAML matrix entries.
- Adding a flag = one-line edit to the `.env` file. No YAML structural changes.
- Diff-friendly in PR review.
- Aligns with the AGENTS.md policy ("ASK THE USER which preset… update `ci/presets/`").

**Alternatives considered**:
- *Inline `env:` block in workflow YAML*: Spreads truth across YAML and shell, harder to grep.
- *JSON config*: Requires `jq` parsing in shell, more brittle than `source`.

### D3: Workflow structure — reusable + thin caller

**Decision**:
- `.github/workflows/build-image.yml` — reusable workflow (`workflow_call`), parameterized by `tool` and `preset`.
- `.github/workflows/build-opencode.yml` — caller workflow, invokes `build-image.yml` with a matrix over presets.

**Rationale**:
- Adding `ai-claude` to CI later = creating a new caller file `build-claude.yml` with 10 lines, no duplication of build logic.
- Single place to fix bugs in the build pipeline.
- Matches the pattern already used for npm publish (`publish-stable.yml` calls `nano-step/shared-workflows/...`).

### D4: Tag scheme — rolling + sha + semver

**Decision**: Every build pushes 3 tags per preset:
- `:<preset>` — rolling latest (e.g., `:base`, `:full`)
- `:<preset>-sha-<short>` — immutable per commit
- `:<preset>-v<x.y.z>` — semver, derived from `package.json` version

**Rationale**:
- Rolling tag for casual users.
- SHA tag for reproducibility (CI/CD pinning, debugging).
- Semver tag for users who want to pin to a release.

### D5: Trigger — changes-filter + manual dispatch

**Decision**:
- `push` to `master` when any of these paths change:
  - `lib/install-base.sh`, `lib/install-opencode.sh`
  - `skills/rtk/**`, `skills/rtk-setup/**`, `skills/dd-pup/**`
  - `scripts/od-status`, `scripts/od-health`
  - `ci/presets/*.env`
  - `.github/workflows/build-image.yml`, `.github/workflows/build-opencode.yml`
  - `dockerfiles/opencode/**`, `dockerfiles/base/**`
- `workflow_dispatch` manual trigger.

**Rationale**:
- Mirrors the changes-filter pattern already proven in `.gitlab-ci.yml`.
- Avoids rebuilding 15-20 min for unrelated commits.

### D6: Build cache — GitHub Actions cache (`type=gha`)

**Decision**: Use `cache-from: type=gha` and `cache-to: type=gha,mode=max` on `docker/build-push-action@v6`, scoped per preset.

**Rationale**:
- GHA cache is free for public repos, 10GB total per repo.
- `mode=max` exports all intermediate layers — Rust toolchain stage cached across runs.
- Same warm-cache build drops from ~15 min to ~3-5 min.

### D7: `bin/ai-run` registry default — switch to ghcr.io, allow override

**Decision**:
- Default `AI_IMAGE_REGISTRY=ghcr.io/nano-step/ai-opencode` when `AI_IMAGE_SOURCE=registry`.
- Default `AI_IMAGE_TAG=base`.
- Users can override via env var.

**Rationale**:
- ghcr.io is now the source of truth for published images.
- GitLab users have an escape hatch.

## Risks / Trade-offs

- **Risk**: ghcr.io image becomes stale / `opencode.ai/install` returns a broken binary → users pull broken image.
  - **Mitigation**: `workflow_dispatch` allows manual rebuild without code change. Versioned SHA tags allow rollback.

- **Risk**: Switching default registry breaks existing users who have `AI_IMAGE_SOURCE=registry` set.
  - **Mitigation**: Document the change in README + CHANGELOG. Document `AI_IMAGE_REGISTRY` escape hatch.

- **Risk**: `:full` preset image (~2.7GB) blows up GHA cache quota (10GB total per repo).
  - **Mitigation**: Start with `mode=max` and monitor. Scope cache per-preset to reduce contention.

- **Trade-off**: Multi-arch deferred → Mac M-series users will run amd64 image under Rosetta/QEMU.
  - **Acceptance**: Most opencode usage is I/O bound. Add `arm64` in follow-up change.

- **Trade-off**: ghcr.io pull is anonymous (no auth needed for public packages) but has rate limits (100 pulls / 6 hours / IP for anon).
  - **Acceptance**: Affects << 1% of users. Document workaround (login with PAT).

## Migration Plan

**Phase 1 — Ship CI without breaking anything**:
1. Add `ci/presets/{base,full}.env`, `build-image.yml`, `build-opencode.yml`.
2. Remove `build-base` and `build-tools` jobs from `ci.yml` (keep `lint`).
3. Manual `workflow_dispatch` first build to seed ghcr.io.

**Phase 2 — Switch default registry in `bin/ai-run`**:
1. Change default `IMAGE` URL from GitLab to ghcr.io.
2. Add `AI_IMAGE_REGISTRY` and `AI_IMAGE_TAG` env vars.
3. Document in README.

**Rollback strategy**:
- If ghcr.io publish fails: workflow exits non-zero, no image pushed, no user impact.
- If `bin/ai-run` change breaks: revert the registry URL change; users fall back to GitLab via `AI_IMAGE_REGISTRY` env var.
- If preset contents are wrong: edit `ci/presets/<preset>.env` and re-run `workflow_dispatch`.

## Open Questions

- **Q1**: Should we delete the `build-base` / `build-tools` jobs from `ci.yml` immediately? — **Yes**. They duplicate the new pipeline and waste CI minutes.
- **Q2**: Should `workflow_dispatch` accept a `preset` input? — **Yes**, optional, default both. Lets the maintainer rebuild a single preset.
- **Q3**: Version tag source? — **`package.json` version**, to match `publish-stable.yml`'s semver source of truth.
