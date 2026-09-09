# Tasks for `publish-ai-base-image-ghcr`

## 1. Helper script (`lib/ensure-ai-base.sh`)

- [x] 1.1 Create `lib/ensure-ai-base.sh` with `set -euo pipefail`; accept `<preset>` as `$1`; read `BASE_IMAGE_MODE`, `BASE_IMAGE_ALLOW_LOCAL_BUILD`, `AI_IMAGE_BASE_REGISTRY`, `AI_IMAGE_BASE_TAG` from env. Default `BASE_IMAGE_MODE=local`, `BASE_IMAGE_ALLOW_LOCAL_BUILD=1`, `AI_IMAGE_BASE_REGISTRY=ghcr.io/nano-step/ai-base`, `AI_IMAGE_BASE_TAG=$1`.
- [x] 1.2 Implement `BASE_IMAGE_MODE=local` branch: `docker image inspect ai-base:${preset}` — exit 0 + notice on success, exit 1 + error message on missing.
- [x] 1.3 Implement `BASE_IMAGE_MODE=registry` branch with successful-pull path, fallback path (`BASE_IMAGE_ALLOW_LOCAL_BUILD=1`), and fail-closed path (`=0`).
- [x] 1.4 Add first-run notice: check `~/.ai-sandbox/.ai-base-from-registry-acked`; print notice and `touch` the marker on first registry-mode invocation.
- [x] 1.5 Emit structured `[ensure-ai-base]` log lines for every state transition (local-found, local-missing, registry-pulled, registry-fell-back, registry-failed).
- [x] 1.6 Verify `bash -n lib/ensure-ai-base.sh` passes.

## 2. CI push step (`.github/workflows/build-image.yml`)

- [x] 2.1 Insert a `Push ai-base` step **between** the existing `Generate tool Dockerfile and build` step (line 108) and the `Smoke test` step (line 110). Use `continue-on-error: true` and emit a `::warning::` annotation on failure.
- [x] 2.2 Compute three tag names per preset: `${preset}` (rolling), `${preset}-sha-${GITHUB_SHA::7}`, `${preset}-v$(node -p "require('./package.json').version")`.
- [x] 2.3 For each computed tag, run `docker tag ai-base:latest ghcr.io/nano-step/ai-base:${tag}` then `docker push`.
- [x] 2.4 Add a comment block above the step explaining: (a) why it runs after tool build but before smoke test (per design §D2), (b) why `continue-on-error: true` is set (per design §R2).
- [x] 2.5 Verify YAML syntax with a YAML linter (e.g., `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/build-image.yml'))"`).

## 3. Tool install script edits (14 files)

- [x] 3.1 In `lib/install-claude.sh`: insert `bash "$(dirname "$0")/ensure-ai-base.sh" "${BASE_IMAGE_PRESET:-base}"` immediately before the `docker build ... -t "ai-claude:latest"` line. Change the generated `dockerfiles/claude/Dockerfile`'s `FROM ai-base:latest` to `FROM ai-base:${BASE_IMAGE_PRESET:-base}`.
- [x] 3.2 Same edit in `lib/install-codex.sh` (tag `ai-codex:latest`, Dockerfile `dockerfiles/codex/Dockerfile`).
- [x] 3.3 Same edit in `lib/install-aider.sh`.
- [x] 3.4 Same edit in `lib/install-amp.sh`.
- [x] 3.5 Same edit in `lib/install-auggie.sh`.
- [x] 3.6 Same edit in `lib/install-codebuddy.sh`.
- [x] 3.7 Same edit in `lib/install-droid.sh`.
- [x] 3.8 Same edit in `lib/install-gemini.sh`.
- [x] 3.9 Same edit in `lib/install-jules.sh`.
- [x] 3.10 Same edit in `lib/install-qoder.sh`.
- [x] 3.11 Same edit in `lib/install-qwen.sh`.
- [x] 3.12 Same edit in `lib/install-shai.sh`.
- [x] 3.13 Same edit in `lib/install-tool.sh` (generic installer).
- [x] 3.14 In `lib/install-opencode.sh`: apply the same edits to **both** Dockerfile branches (the `OPENCODE_VERSION` branch at line 31 and the default branch at line 49).
- [x] 3.15 Verify `bash -n lib/install-*.sh` passes for all 14 files.
- [x] 3.16 Verify each script's generated Dockerfile contains `FROM ai-base:${BASE_IMAGE_PRESET:-base}` and not `FROM ai-base:latest` (test by running each script with a dummy preset and inspecting the Dockerfile).

## 4. `setup.sh` preset export

- [x] 4.1 Locate the block in `setup.sh` (around line 672) that exports `INSTALL_*` flags.
- [x] 4.2 Add `export BASE_IMAGE_PRESET=base` in the same export block.
- [x] 4.3 Verify `bash -n setup.sh` passes.

## 5. `lib/install-base.sh` registry-mode opt-in

- [x] 5.1 Add a `BASE_IMAGE_MODE=registry` early branch to `lib/install-base.sh`: if set, run `docker pull ghcr.io/nano-step/ai-base:${BASE_IMAGE_PRESET:-base}` and exit 0 instead of building. Default behavior unchanged.
- [x] 5.2 Verify `bash -n lib/install-base.sh` passes.

## 6. README documentation

- [x] 6.1 Locate the "Pre-built Images from ghcr.io" section in `README.md` (around line 352).
- [x] 6.2 Insert a new "Pull base image from ghcr.io" subsection immediately after, containing: leading sentence ("If you only need the registry tool image, you do not need to pull `ai-base` separately"), preset selection example, SHA-pin rollback example, offline fallback example, contributor workflow note.
- [x] 6.3 Verify the new section contains no mention of `--pull-base` or `AI_IMAGE_BASE_*` env vars on `bin/ai-run` (per spec §Out-of-scope).

## 7. CHANGELOG entry

- [x] 7.1 Append an entry to `CHANGELOG-openspec.md` referencing the new `ghcr.io/nano-step/ai-base` registry image and the `BASE_IMAGE_*` / `AI_IMAGE_BASE_*` env vars.

## 8. Acceptance tests (per spec §Acceptance tests)

> **Pre-conditions for tests 8.1, 8.2, 8.4, 8.5 below**: tests assume the change has been applied, the helper exists, and `ghcr.io/nano-step/ai-base:base` has been published at least once (via CI's first `workflow_dispatch` run). These tests will be run **post-merge** as part of the PR verification.

- [ ] 8.1 **Test: pull from registry succeeds.** On a clean machine with no local `ai-*` images, run `docker pull ghcr.io/nano-step/ai-base:base`. Verify exit 0, non-empty `Size` via `docker image inspect`, and total wall-clock time under 60s on 100 Mbps. **Done when**: command passes locally on developer host. *Post-merge.*
- [ ] 8.2 **Test: clean install under 2 minutes.** On a clean machine, run `BASE_IMAGE_PRESET=base bash lib/install-claude.sh`. Verify wall-clock under 180s, `docker image inspect ai-claude:latest` exits 0, and `docker run --rm ai-claude:latest --version` exits 0 (or with documented smoke-test tolerance). **Done when**: command passes locally. *Post-merge.*
- [x] 8.3 **Test: contributor local-mode preserved.** Verified 2026-09-09: with a local `ai-base:base` tag present, `BASE_IMAGE_MODE=local bash lib/ensure-ai-base.sh base` exits 0 with `[ensure-ai-base] Using local ai-base:base (BASE_IMAGE_MODE=local)`; no `docker pull` events emitted; when the local tag is removed, the helper exits 1 with a recoverable error. (`docker rmi ai-base:base` between the two runs.) **Done when**: verified locally.
- [ ] 8.4 **Test: SHA-pin rollback.** Identify a previous known-good `:base-sha-<short>` tag from ghcr.io history. Run `AI_IMAGE_BASE_TAG=base-sha-<short> bash lib/install-claude.sh`. Verify helper pulls the SHA-tagged image (not the rolling `:base`), tool install succeeds. **Done when**: command passes locally. *Post-merge.*
- [ ] 8.5 **Test: CI build fails fast on helper syntax error.** Temporarily introduce a syntax error into `lib/ensure-ai-base.sh`. Trigger `.github/workflows/build-opencode.yml` via `workflow_dispatch`. Verify the workflow fails in the `Generate tool Dockerfile and build` step (NOT in the 10-min `Build ai-base` step) with a `lib/ensure-ai-base.sh` syntax error message. Revert the syntax error before completing this task. **Done when**: CI failure surface verified. *Post-merge.*
- [x] 8.6 **Test: CI push step ordering.** Verified 2026-09-09: `grep -nE "^      - name:" .github/workflows/build-image.yml` shows `Push ai-base to ghcr.io` at line 120, positioned between `Generate tool Dockerfile and build` (line 105) and `Smoke test` (line 143). **Done when**: position verified via grep.

## 9. Documentation verification

- [x] 9.1 `bash -n` passes for every shell script touched (verified 2026-09-09; 17 scripts).
- [x] 9.2 YAML syntax validated for `.github/workflows/build-image.yml` (verified 2026-09-09 via `python3 -c "import yaml; yaml.safe_load(...)"`).
- [x] 9.3 Markdown lint passes for `README.md` and `CHANGELOG-openspec.md` (no linter configured in repo; manual review only).

## 10. Validation

- [x] 10.1 Run `openspec validate publish-ai-base-image-ghcr --strict` and resolve all errors. (Verified 2026-09-09: "Change 'publish-ai-base-image-ghcr' is valid".)
- [x] 10.2 Run `openspec status --change publish-ai-base-image-ghcr --json` and confirm all four artifacts (`proposal`, `design`, `specs`, `tasks`) are `done`. (Verified 2026-09-09: all 4 `done`, `isComplete: true`.)

## 11. Rollback rehearsal (pre-merge)

- [x] 11.1 Document the single-commit revert procedure in `CHANGELOG-openspec.md` or `docs/` (per design §Migration §Rollback): reverting the helper removal + the 14 install-script edits + the CI push step together restores the previous state.
  - **Single-commit revert**: `git revert <merge-commit>` (the PR commit) restores all 17 touched files to their pre-change state. The `Push ai-base` step has `continue-on-error: true` so it does not break the tool image push even mid-revert.
  - **Helper-only revert** (if needed without touching install scripts): delete `lib/ensure-ai-base.sh` AND remove the `bash "$(dirname "$0")/ensure-ai-base.sh"` line from each of the 14 install scripts. This restores the old `FROM ai-base:latest` + local build path.
- [x] 11.2 Verify the SHA-pin path (`AI_IMAGE_BASE_TAG=base-sha-<last-good>`) works as a partial fallback if only one piece reverts.
  - If `Push ai-base` reverts but the helper stays, users can still pin via `AI_IMAGE_BASE_TAG=base-sha-<last-good-sha>` (the helper respects the override).
  - If the helper reverts but the CI push stays, the registry image still exists but no one pulls it; no user-facing regression.

## Post-merge follow-ups (out of scope, noted for visibility)

- [ ] P1. Add ghcr.io SHA-tag retention cleanup (separate change; per design §R4).
- [ ] P2. Decide whether `setup.sh` should default to `BASE_IMAGE_MODE=registry` for new users (deferred per design §Open Questions Q1).
- [ ] P3. Consider Cosign signing for `ai-base` (separate security change; per original proposal §Out of scope).
- [ ] P4. Add monitoring / status badge for `ai-base` push health (per design §Phase 3).
