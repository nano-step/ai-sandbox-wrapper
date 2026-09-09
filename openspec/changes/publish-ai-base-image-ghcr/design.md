## Context

The repository ships a two-layer Docker image architecture:

- **`ai-base:latest`** — built locally by `lib/install-base.sh` from `node:22-bookworm-slim`. Includes 12 `INSTALL_*` flag-controlled tools (openspec, ux-pro-max via uipro-cli, Datadog pup via multi-stage Rust, RTK via multi-stage Rust, spec-kit, acli via APT repo, Go 1.23 + sqlc/goose/golangci-lint, GitHub CLI via APT repo, Playwright + Chrome DevTools MCP, etc.). ~10–15 min cold build.
- **`ai-<tool>:latest`** (one per tool) — extends `FROM ai-base:latest` and adds the tool's native binary or npm package. 13 named scripts (`claude`, `codex`, `aider`, `amp`, `auggie`, `codebuddy`, `droid`, `gemini`, `jules`, `qoder`, `qwen`, `shai`, `opencode`) plus the generic `install-tool.sh`. `lib/install-kilo.sh` uses `FROM node:22-slim` and is **not** part of this architecture.

CI publishes the per-tool images to `ghcr.io/nano-step/ai-opencode:*` (via `.github/workflows/build-opencode.yml` → `build-image.yml`) but **never publishes `ai-base`**. Every developer host and every fresh CI runner pays the full base build cost. There is no canonical digest for `ai-base` across machines — different hosts produce slightly different images due to OS package mirror state, Rust crate freshness, and Node module drift.

The user has asked: **publish `ai-base` to a registry so installs can pull it instead of building it manually.**

This change adds the missing registry-publish layer for `ai-base`, ships a small local helper to consume the published image, and updates the 14 install scripts to use it. It does NOT touch `bin/ai-run` (the runtime launcher) — see Decisions §D7.

## Goals / Non-Goals

**Goals:**

- After CI completes a build, `ghcr.io/nano-step/ai-base:<preset>` (and SHA + version tags) is publicly pullable.
- A developer on a clean machine running `bash lib/install-claude.sh` for the first time completes the install in **under 2 minutes** (vs the current ~15 min) via `docker pull`.
- A developer iterating on `lib/install-base.sh` locally can still build `ai-base:latest` from source via `BASE_IMAGE_MODE=local` (the default) without ever pulling from the registry.
- A bad `:base` push is recoverable: users can pin to a previous SHA via `AI_IMAGE_BASE_TAG=base-sha-<old-sha> bash lib/install-<tool>.sh`.
- The CI build of `ai-opencode:base` continues to pass the existing smoke test, and now additionally publishes the `ai-base:base` it depends on.

**Non-Goals:**

- Modifying `bin/ai-run` (the runtime launcher). It already uses `ai-sandbox:latest` locally or `ghcr.io/nano-step/ai-opencode:base` from the registry — neither path depends on a runtime pull of `ai-base`. Any future `--pull-base` flag belongs to a separate change that adds a Dockerfile-assembly mode to `bin/ai-run`.
- Multi-arch builds (`linux/arm64`). Consistent with the existing `ai-opencode` deferred decision.
- Modifying the unified `ai-sandbox:latest` flow (`lib/build-sandbox.sh` + `setup.sh`). This flow inlines the base Dockerfile content directly and does not need `ai-base:latest` at runtime; touching it would expand scope into the default install path.
- Cosign signing, SBOM generation, retention cleanup — all deferred to dedicated security/hardening changes.

## Decisions

### D1: Tag scheme — mirrors the existing `ai-opencode` pattern

**Decision**: Each preset produces three tags:

- `:base` / `:full` — rolling latest
- `:base-sha-<7-char-short>` / `:full-sha-<7-char-short>` — per commit
- `:base-v<semver>` / `:full-v<semver>` — per `package.json` release

**Rationale**: Reuses the proven tag scheme from `openspec-archive/changes/publish-opencode-image-ghcr/design.md` D4. Same `:rolling`, `:sha`, `:semver` semantics; users already know how to consume the tool image.

**Alternatives considered**:

- Single tag (`:latest` only): loses rollback and reproducibility.
- Date-based tags (`:2026-09-09`): not sortable, no semver alignment, breaks existing automation.

### D2: CI push step runs **after** tool build, **before** smoke test

**Decision**: The new `Push ai-base` step is inserted **between** the `Generate tool Dockerfile and build` step (`.github/workflows/build-image.yml` line 108) and the `Smoke test` step (line 110).

**Rationale**: The smoke test runs `ai-<tool>:latest` which depends on `ai-base:latest` — the same image we are about to push. By pushing **after** the tool build but **before** the smoke test, we catch two failure modes early:

1. If `ai-base:latest` is broken, the smoke test fails → no broken image published.
2. If the push itself fails, we have already verified the tool image locally; `continue-on-error: true` lets the tool-image push still proceed.

**Alternatives considered**:

- Push after smoke test: a broken base gets published before being caught. Rejected per Reviewer B's S5 finding.
- Push as a separate job: 2× the GHA minutes for the same result. Rejected.

### D3: `lib/ensure-ai-base.sh` is idempotent, not a dry-run / `--apply` pair

**Decision**: The helper uses `set -euo pipefail`, has a single `ensure <preset>` function, and exits 0 on success or 1 on hard failure (with a recoverable message). No `--dry-run` / `--apply` split.

**Rationale**: Per Reviewer A's M8 finding, the helper interacts with `docker` (pull, tag, inspect) and the network (ghcr.io). These operations are inherently idempotent — re-running them produces the same end state. A `--dry-run` / `--apply` split (as in `migrate-opencode-db.sh`) adds complexity for no safety benefit; users who want to preview behavior can read the script.

The helper is **not** a `migrate-opencode-db.sh` analog — that script is a one-shot migration of irrecoverable user data; this helper is a re-runnable environment setup. The shape must reflect that.

### D4: `BASE_IMAGE_MODE=local` short-circuits the helper at tool-install time

**Decision**: When the helper is invoked with `BASE_IMAGE_MODE=local` (the default), it **does not pull** and **does not retag**. It verifies a local `ai-base:<preset>` tag exists and exits 0 with a notice.

**Rationale**: Per Reviewer B's S7 finding. Without this short-circuit, a contributor iterating on `lib/install-base.sh` who runs `bash lib/install-claude.sh` to test their build has their local `ai-base:latest` silently overwritten by the registry image. The contributor workflow is protected by:
1. The default `BASE_IMAGE_MODE=local` (set by `setup.sh`'s export).
2. The helper's local-mode no-pull behavior.

**Alternatives considered**:

- Always pull, ignore local: breaks contributor workflow.
- Pull only if local missing AND `BASE_IMAGE_ALLOW_LOCAL_BUILD=1`: same as default behavior, but contributor must remember to set the flag. Worse UX.

### D5: `BASE_IMAGE_ALLOW_LOCAL_BUILD=1` is the default (flipped from original proposal)

**Decision**: When `BASE_IMAGE_MODE=registry` and `docker pull` fails, the helper falls back to `bash lib/install-base.sh` by default. To opt out (e.g., for CI parity), set `BASE_IMAGE_ALLOW_LOCAL_BUILD=0`.

**Rationale**: Per Reviewer A's M6 finding. The original proposal defaulted to fail-closed (`=0`), which contradicts the user's stated goal — if the registry is down or the user is offline, they cannot install any tool. The new default matches the user's intent: "pull when possible, build when necessary, never block installation on a registry outage."

**Alternatives considered**:

- Fail-closed (`=0` default): contradicts user intent. Rejected.
- Auto-detect connectivity (curl probe ghcr.io): adds a 5s latency tax on every install for marginal benefit. The default fallback is cheap.

### D6: Tool Dockerfile `FROM` becomes `ai-base:${BASE_IMAGE_PRESET:-base}`

**Decision**: All 14 install scripts change the generated Dockerfile's `FROM ai-base:latest` line to `FROM ai-base:${BASE_IMAGE_PRESET:-base}`.

**Rationale**: Per Reviewer A's H2 and Reviewer B's S6 findings. With `FROM ai-base:latest`, the tool image always resolves to whatever local `:latest` points to — even if the helper just pulled a fresh `:base`. Two tags with two different digests creates silent staleness. By making the tag explicit (`ai-base:base` or `ai-base:full`), the helper's choice of tag is the one the tool image uses.

**Alternatives considered**:

- Keep `FROM ai-base:latest`, helper always retags pulled `:base` → `:latest`: overwrites contributor's local development build. Rejected.
- Keep `FROM ai-base:latest`, helper compares digests and warns on mismatch: adds complexity; doesn't fix the staleness. Rejected.

### D7: `bin/ai-run` is unchanged — no `--pull-base`, no `AI_IMAGE_BASE_*`

**Decision**: The proposal originally included `bin/ai-run` `--pull-base` / `--no-pull-base` flags and `AI_IMAGE_BASE_REGISTRY` / `AI_IMAGE_BASE_TAG` / `AI_IMAGE_BASE_MAX_AGE_DAYS` env vars. All are dropped.

**Rationale**: Per Reviewer A's H1, H3 findings (independently confirmed by Reviewer B's S1). `bin/ai-run` has **no Dockerfile-assembly path** — verified via `grep -n "Dockerfile\|dockerfiles" bin/ai-run` returning 0 hits in executable code. The script's only `IMAGE` assignment (line 888-892) is for `docker run`, not `docker build`. The two runtime paths:

- **Local** (`AI_IMAGE_SOURCE=local`): `IMAGE=ai-sandbox:latest`. This image is built by `lib/build-sandbox.sh` which **inlines the base Dockerfile content** (`BASE_CONTENT=$(cat "$BASE_DOCKERFILE")`, line 23). It does not depend on `ai-base:latest` at runtime.
- **Registry** (`AI_IMAGE_SOURCE=registry`): `IMAGE=ghcr.io/nano-step/ai-opencode:base`. This is a single combined image produced by CI's `build-image.yml` line 131-138, which already includes all base layers (verified by `docker history ghcr.io/nano-step/ai-opencode:base` showing the `apt-get install ... chromium` step that is part of base).

Neither path has any code point where pulling `ai-base` separately would be observable to the user. Adding the flag is dead-letter; adding the env vars is dead-letter.

### D8: `BASE_IMAGE_PRESET=base` exported by `setup.sh`

**Decision**: `setup.sh` exports `BASE_IMAGE_PRESET=base` in the block where it exports `INSTALL_*` flags (around line 672, verified by Reviewer A's M7).

**Rationale**: Without this, contributors running `setup.sh` get the helper's built-in default (`base`) silently. Exporting it explicitly:
1. Makes the preset choice discoverable in `env | grep BASE_IMAGE_PRESET`.
2. Allows easy switching: `BASE_IMAGE_PRESET=full bash setup.sh`.
3. Echoes the preset into build logs.

### D9: First-run migration notice, not a one-shot migration

**Decision**: On first helper invocation, the helper prints a one-time notice and creates a marker file at `~/.ai-sandbox/.ai-base-from-registry-acked`. On subsequent invocations, the notice is suppressed.

**Rationale**: Per Reviewer B's S14 finding. Users with existing local `ai-base:latest` from the old workflow should see a clear message that explains:
- The base image is now pulled from ghcr.io (not built locally) under `BASE_IMAGE_MODE=registry`.
- Their local `ai-base:latest` is preserved by `BASE_IMAGE_MODE=local` (default for contributors).

The marker file prevents re-prompting on every run.

## Risks / Trade-offs

- **R1**: Public registry exposes base image contents (no secrets, but exposes dev-tool fingerprinting). → Mitigation: documented in §D7 above and deferred signing/SBOM. The marginal risk matches the existing `ai-opencode` risk.

- **R2**: `Push ai-base` step fails mid-run; tool image push proceeds but base is stale. → Mitigation: `continue-on-error: true` + `::warning::` annotation. Operators see the warning in GitHub Actions UI; subsequent CI runs republish.

- **R3**: Tool Dockerfile `FROM ai-base:${BASE_IMAGE_PRESET:-base}` breaks contributor iteration if contributor forgets `BASE_IMAGE_PRESET=local` default. → Mitigation: helper short-circuits on `BASE_IMAGE_MODE=local` regardless of preset; default mode is `local`; preset defaults to `base`. Contributors must opt into `BASE_IMAGE_MODE=registry` to be affected.

- **R4**: `:base-sha-*` tags accumulate indefinitely. → Mitigation: deferred to a separate ghcr.io retention change. Noted in tasks.md as future work.

- **R5**: Two independent rolling tags (`:base` vs `:full`) can drift if a contributor forgets to publish `:full` updates. → Mitigation: CI builds and pushes both presets from the same `build-image.yml` invocation, gated by the same `paths:` filter. Drift is impossible from a single CI run; only possible if CI itself fails on one preset.

- **R6**: A bad `:base` push is the user's regression vector. → Mitigation: SHA-pin rollback documented in README + `AI_IMAGE_BASE_TAG` override in the helper. Users can pin to a known-good SHA until the next good push.

- **R7**: Reverting this change in pieces breaks the 14 install scripts (they expect the helper to exist). → Mitigation: tasks.md documents single-commit revert — the helper removal and the install-script edits revert together; the CI push step can be reverted independently.

## Migration Plan

**Phase 1 — Ship the helper and CI push (no user-visible behavior change yet):**

1. Land `lib/ensure-ai-base.sh` with `BASE_IMAGE_MODE=local` default behavior (verify local tag exists, exit 0).
2. Modify 14 install scripts to insert helper call (but with local-mode default, helper is a no-op for existing users).
3. Land CI `Push ai-base` step with `continue-on-error: true` (does not break existing tool push).
4. Manually verify first push via `workflow_dispatch`; confirm `ghcr.io/nano-step/ai-base:base` appears.

**Phase 2 — Enable registry-mode by default for non-contributors:**

5. Update `README.md` with the new `BASE_IMAGE_PRESET=base bash lib/install-<tool>.sh` flow as the **recommended** path for new users.
6. The default `BASE_IMAGE_MODE=local` remains in place; new users explicitly opt into registry-mode OR `setup.sh` could be updated to default to registry-mode in a future change.

**Phase 3 — Post-merge observability (deferred):**

7. Add ghcr.io retention policy (separate change).
8. Add monitoring / status badge for `ai-base` push health.

**Rollback strategy:**

- **Single-commit revert** removes helper, CI step, and 14 install-script edits together. Safe because the helper is only called by those scripts, and CI step has `continue-on-error: true`.
- **SHA-pin** during a partial rollback: if the helper ships but CI push breaks, users can pin via `AI_IMAGE_BASE_TAG=base-sha-<last-good-sha> bash lib/install-<tool>.sh`.

## Open Questions

- **Q1**: Should `setup.sh` be updated to export `BASE_IMAGE_MODE=registry` as the default for new users (instead of `local`)? — **Deferred**. The current `local` default protects contributors; changing it to `registry` would benefit new users but break the contributor UX. Decision deferred to a future "default-to-registry" change.
- **Q2**: Should the helper add a `--check` flag that prints which image would be used without invoking it? — **No**. The existing `docker image inspect ai-base:<preset>` + `docker manifest inspect ghcr.io/.../ai-base:<preset>` commands suffice for debugging. Adds flag surface area for no benefit.
- **Q3**: Should we add Cosign signing for `ai-base` as part of this change? — **No**, per the original proposal's out-of-scope list. Separate security-focused change.
- **Q4**: Where should the `~/.ai-sandbox/.ai-base-from-registry-acked` marker live? — **Resolved**: under `~/.ai-sandbox/` (the existing per-user config dir, created by `setup.sh`). Mirrors the `~/.ai-sandbox/.merge-prompted` marker pattern from `openspec-archive/changes/consolidate-opencode-db/`.
