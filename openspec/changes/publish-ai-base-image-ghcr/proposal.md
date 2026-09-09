## Why

The repository's CI pipeline (`build-image.yml`) builds `ai-base` locally with `push: false` and **never publishes it to any registry**. Only the per-tool images (`ai-opencode`, etc.) reach `ghcr.io/nano-step/ai-opencode:*`. This forces every local re-installation of an agent image (`ai-claude`, `ai-codex`, `ai-aider`, `ai-amp`, ...) to rebuild `ai-base` from scratch — paying the full 10–15 minute cost of installing openspec, ux-pro-max (uipro-cli), pup, rtk, spec-kit, acli, Go toolchain, GitHub CLI, and the MCP browser packages — even when the user just wants the agent's native binary layered on top. The cache helps in CI, but on developer laptops, on a fresh clone, or on first-time `lib/install-<tool>.sh` runs, the cost is paid every time.

The base image is also **not reproducible across machines**: identical preset flags produce slightly different bytes depending on OS package mirror state, Rust crate freshness, and Node module version drift. Different machines end up with different `ai-base` digests underneath the same tool image, breaking assumptions made by the rest of the system.

Publishing `ai-base` to ghcr.io eliminates the redundant local rebuild, removes the need for the host to have Rust/Go/Node toolchains to *just install* an agent, and pins a single canonical digest per `(preset, commit)` pair that every downstream tool image can rely on.

## What Changes

### Refinements from adversarial review

This proposal was reviewed by two independent subagents (architecture + delivery). Key amendments before apply:

- **DROP** all `bin/ai-run` changes (`--pull-base` flag, `AI_IMAGE_BASE_*` env vars, `AI_IMAGE_BASE_MAX_AGE_DAYS`). Reviewer A found that `bin/ai-run` has no Dockerfile-assembly path (the only `IMAGE` assignment is for `docker run`, not `docker build`), so these additions would be dead-letter. Reviewer B independently confirmed: the registry tool image path (`AI_IMAGE_SOURCE=registry` → `ghcr.io/nano-step/ai-opencode:base`) already contains the base layers, and the local path (`ai-sandbox:latest`) inlines the base Dockerfile content — so even a hypothetical `--pull-base` would have no consumer.
- **DROP** the proposed `AGENTS.md` edit citing a "Kind B" subheading. Reviewer B verified (`grep -n "Kind B" AGENTS.md` → 0 hits) that the heading does not exist; the proposed edit would have been misfiled. The existing policy in `AGENTS.md` already covers preset policy under a different heading; this change does not modify `AGENTS.md`.
- **CORRECT** the file count from "15 tool install scripts" to **14**: 13 named scripts (`claude`, `codex`, `aider`, `amp`, `auggie`, `codebuddy`, `droid`, `gemini`, `jules`, `qoder`, `qwen`, `shai`, `opencode`) plus `lib/install-tool.sh`. `lib/install-opencode.sh` has two Dockerfile branches and must be edited in both. `lib/install-kilo.sh` uses `FROM node:22-slim` and is NOT in scope.

### Final scope

- **NEW**: After building `ai-base:latest` in `build-image.yml` (after the tool Dockerfile is generated and built, but BEFORE the smoke test), tag the locally-loaded `ai-base:latest` as `:base` (or `:full`) plus `:base-sha-<short>` (or `:full-sha-<short>`) and `:base-v<version>` (or `:full-v<version>`), then `docker push` to `ghcr.io/nano-step/ai-base:*`. Step uses `continue-on-error: true` with a `::warning::` annotation so a transient registry blip does not break the tool image push.
- **NEW**: Shared helper `lib/ensure-ai-base.sh <preset>` that:
  - If `BASE_IMAGE_MODE=local` (default), verifies a local `ai-base:<preset>` exists and exits 0 with a notice — does NOT pull.
  - Otherwise (`BASE_IMAGE_MODE=registry`), checks `docker image inspect ai-base:<preset>` locally; if missing, runs `docker pull ghcr.io/<registry>/<tag>` where registry and tag come from `AI_IMAGE_BASE_REGISTRY` (default `ghcr.io/nano-step/ai-base`) and `AI_IMAGE_BASE_TAG` (default `<preset>`).
  - On pull failure: if `BASE_IMAGE_ALLOW_LOCAL_BUILD=1` (default ON), prints a warning and falls back to `bash lib/install-base.sh`; if `=0`, exits 1 with a recoverable error message.
  - On first run (marker file `~/.ai-sandbox/.ai-base-from-registry-acked` does not exist), prints a one-time notice about the behavior change.
  - Idempotent — safe to invoke repeatedly. No `--apply` / `--dry-run` split.
- **MODIFIED**: All 14 tool install scripts (`lib/install-{claude,codex,aider,amp,auggie,codebuddy,droid,gemini,jules,qoder,qwen,shai,opencode}.sh` + `lib/install-tool.sh`) — two changes per script:
  1. Insert `bash "$(dirname "$0")/ensure-ai-base.sh" "${BASE_IMAGE_PRESET:-base}"` before the `docker build ... -t "ai-$TOOL:latest"` line.
  2. Change the generated Dockerfile's `FROM ai-base:latest` to `FROM ai-base:${BASE_IMAGE_PRESET:-base}` so the tag is explicit and the helper's choice of tag matters (Reviewer B's S6 finding: otherwise tool scripts silently use stale local `:latest` regardless of pull).
  `lib/install-opencode.sh` has two Dockerfile branches (the `OPENCODE_VERSION` branch and the default branch); both must be updated.
- **MODIFIED**: `setup.sh` exports `BASE_IMAGE_PRESET=base` by default for any tool install scripts it invokes (Reviewer A's M7 finding: without this, the helper's default is used silently and contributors have no way to self-audit which preset they're building against).
- **MODIFIED**: `lib/install-base.sh` adds a `BASE_IMAGE_MODE=registry` opt-in path for CI runners that want to skip the base build (reviewer A's M2 finding: the CI build already loads `ai-base:latest` locally, so registry mode is a no-op for CI but available for parity). When invoked from the helper's fallback path, it uses the existing local build behavior unchanged.
- **MODIFIED**: `ci/presets/base.env` and `ci/presets/full.env` are unchanged (already declarative); the new CI step reads them, builds the corresponding `ai-base`, and pushes the resulting image with a tag that encodes the preset.
- **POLICY** (preserved from existing `AGENTS.md`): Preset contents stay declarative in `ci/presets/*.env`. Adding a new `INSTALL_*` flag to `lib/install-base.sh` requires asking the user which preset(s) include it, then editing exactly those `.env` files.

## Capabilities

### New Capabilities

- `ai-base-registry-image`: Defines what `ai-base` images exist on ghcr.io (one per preset, with rolling/sha/version tags), how they're built and pushed, how the local helper pulls them, the `BASE_IMAGE_MODE` / `BASE_IMAGE_ALLOW_LOCAL_BUILD` / `AI_IMAGE_BASE_*` knobs, and the rollback contract (SHA-pin via `AI_IMAGE_BASE_TAG`).

### Modified Capabilities

- *(none)* — Per Reviewer A's L2 finding, no existing requirement in the archived `base-image` spec references registry, publishing, or delivery. The change adds a **new** capability (`ai-base-registry-image`) for the registry dimension rather than modifying the existing `base-image` capability, which keeps the spec delta focused on what is actually new.

## Impact

**Affected code**:

- `.github/workflows/build-image.yml` — add a `Push ai-base` step **between** the `Generate tool Dockerfile and build` step (line 108) and the `Smoke test` step (line 110). Step uses `continue-on-error: true` with a `::warning::` annotation. Step tags `:base` (or `:full`) + `:base-sha-<short>` (or `:full-sha-<short>`) + `:base-v<version>` (or `:full-v<version>`) and pushes each. Per Reviewer B's S5 finding, the step MUST run after the tool build so the smoke test verifies the actual base the tool depends on, and MUST be `continue-on-error` per S11 so a transient registry blip does not break the tool image push.
- `lib/ensure-ai-base.sh` — NEW idempotent shell helper. Accepts `<preset>` as `$1`. Shape: `set -euo pipefail`; no `--apply` / `--dry-run` split (different from `migrate-opencode-db.sh` — registry pulls are idempotent and re-runnable, DB migrations are not). Reads `BASE_IMAGE_MODE`, `BASE_IMAGE_ALLOW_LOCAL_BUILD`, `AI_IMAGE_BASE_REGISTRY`, `AI_IMAGE_BASE_TAG` from env. Emits structured `[ensure-ai-base]` log lines for grep-ability.
- `lib/install-{claude,codex,aider,amp,auggie,codebuddy,droid,gemini,jules,qoder,qwen,shai,opencode}.sh` (13 files) and `lib/install-tool.sh` (1 file) — **14 files total**. Two changes per file: (a) insert helper call before `docker build`, (b) change generated Dockerfile's `FROM ai-base:latest` to `FROM ai-base:${BASE_IMAGE_PRESET:-base}`. `lib/install-opencode.sh` requires editing **both** Dockerfile branches (the `OPENCODE_VERSION` branch and the default branch).
- `lib/install-base.sh` — add `BASE_IMAGE_MODE=registry` env var opt-in path that pulls from registry instead of build (CI-only optimization; default `local`). Existing local build path unchanged.
- `setup.sh` — export `BASE_IMAGE_PRESET=base` in any block that exports `INSTALL_*` flags (per Reviewer A's M7).
- `README.md` — add "Pull base image from ghcr.io" section covering: preset selection, SHA-pin rollback (`AI_IMAGE_BASE_TAG=base-sha-<old-sha>`), `BASE_IMAGE_ALLOW_LOCAL_BUILD=1` fallback, contributor workflow with `BASE_IMAGE_MODE=local`. Lead with: "If you only need the registry tool image, you do not need to pull `ai-base` separately" (per Reviewer A's L4).
- `CHANGELOG-openspec.md` — append entry referencing this change.

**NOT affected** (per debate outcomes):

- `bin/ai-run` — **no changes**. Reviewer A's H1 finding: `bin/ai-run` has no Dockerfile-assembly path; the proposed `--pull-base` flag and `AI_IMAGE_BASE_*` env vars would be dead-letter. Reviewer B's S1 finding independently confirmed.
- `AGENTS.md` — **no changes**. Reviewer B verified that the "Kind B" subheading the proposal originally cited does not exist (`grep -n "Kind B" AGENTS.md` → 0 hits). Existing `AGENTS.md` policy already covers preset flag changes.
- `.github/workflows/build-opencode.yml` paths-filter — **no changes**. The existing filter already includes `lib/install-base.sh`, which transitively rebuilds the base. Adding `lib/ensure-ai-base.sh` to the filter is redundant (per Reviewer A's L3).

**Affected systems**:

- GitHub Container Registry — new package `ghcr.io/nano-step/ai-base` appears alongside the existing `ghcr.io/nano-step/ai-opencode`. Per preset: `:base` (rolling) + `:base-sha-<short>` (per commit) + `:base-v<version>` (per release). Same pattern as `ai-opencode`. Both presets together are ~3.5 GB unpacked; compressed ghcr.io storage ~3 GB (well under the 10 GB free-tier allowance).
- GitHub Actions minutes — adds ~30s per CI run (3 extra `docker push` × ~10s). Negligible (~0.5% of the 2,000 min/month free tier). Per Reviewer B's S9 finding.
- Developer host — first tool install on a clean machine drops from ~10–15 min to ~1.5 min (one `docker pull` ~30s + tool build ~30s). Subsequent installs use the cached local copy. No Rust/Go/Node toolchain required on the host for tool install (assuming `BASE_IMAGE_ALLOW_LOCAL_BUILD=1`, the new default).

**Backward compatibility**:

- The default `BASE_IMAGE_MODE=local` for the helper means existing contributor workflows (iterating on `lib/install-base.sh`) are **unaffected** when the contributor sets `BASE_IMAGE_MODE=local`. Per Reviewer B's S7 finding, this short-circuit must be honored at tool-install time, not just at base-install time.
- The default `BASE_IMAGE_ALLOW_LOCAL_BUILD=1` (flipped from the original proposal's `=0`) means a failed pull still falls back to a local build, matching the user's stated desire ("không phải build thủ công" = don't manually build, but also don't fail closed on poor network). To opt out of the fallback (e.g., for CI parity), set `BASE_IMAGE_ALLOW_LOCAL_BUILD=0`.
- The default `AI_IMAGE_BASE_TAG=base` matches what was already implicit; existing local `ai-base:latest` images continue to work for the contributor path.
- CI changes are additive: the `ai-opencode` build still uses the locally-loaded `ai-base:latest` (no regression); the new push is a fan-out of the same image with `continue-on-error: true` so it cannot break the existing tool push.
- **Migration**: existing users with locally-built `ai-base:latest` from the old workflow will see a one-time notice on first helper invocation explaining the behavior change. The local `ai-base:latest` is preserved (helper does not retag unless `BASE_IMAGE_MODE=registry` is active and a fresh image is pulled).

**Out of scope** (explicitly deferred):

- **Multi-arch `ai-base`** (`linux/amd64` + `linux/arm64`). Per Reviewer A's L1, this is consistent with the existing `ai-opencode` choice and adds ~2× GHA minutes. Separate change.
- **`ai-sandbox:latest` (unified local image) path**. Per Reviewer A's M3 finding, `lib/build-sandbox.sh` line 23 inlines the base Dockerfile content directly — `setup.sh` calls `lib/build-sandbox.sh` and produces `ai-sandbox:latest` without going through `ai-base:latest`. The registry-pulled `ai-base` is not used by the default `setup.sh` flow today. Adding it would require changing `lib/build-sandbox.sh` to pull from registry instead of inlining, which is a larger refactor and is **deferred** to a separate change. This change only affects the per-tool install path.
- **Cosign signing of `ai-base`**. Deferred to a future security-focused change. Per Reviewer A's M5, the marginal fingerprinting risk (an attacker who knows the team uses RTK/Pup/acli can enumerate the image contents) is identical to the existing `ai-opencode` registry risk.
- **SBOM / provenance attestation for `ai-base`**. Deferred.
- **ghcr.io SHA-tag retention policy**. Per Reviewer B's S10, SHA tags accumulate indefinitely. Cleanup is a separate concern; noted but not addressed here.
- **Removing `.gitlab-ci.yml` or the legacy `registry.gitlab.com` path**. Kept untouched.
- **Building `ai-claude`, `ai-amp`, etc. on CI**. Out of scope; the reusable `build-image.yml` workflow already supports them — adding callers is a follow-up.
- **Auto-pinning tool image `FROM ai-base@sha256:...`**. Deferred per the original proposal; the rolling `:base` tag is sufficient for the user's stated goal.
- **Retention cleanup for old `:base-sha-*` tags**. Per Reviewer B's S10, deferred — separate change.
