## 1. Preset definitions

- [x] 1.1 Create `ci/presets/` directory.
- [x] 1.2 Create `ci/presets/base.env` with the flag values specified in `specs/ci-published-images/spec.md`.
- [x] 1.3 Create `ci/presets/full.env` with the flag values specified in `specs/ci-published-images/spec.md`.
- [x] 1.4 Add a header comment to each `.env` file explaining its purpose and pointing to AGENTS.md.

## 2. Reusable build workflow (`build-image.yml`)

- [x] 2.1 Create `.github/workflows/build-image.yml` with `workflow_call` accepting `tool` + `preset` inputs.
- [x] 2.2 Declare job-level `permissions: { contents: read, packages: write }`.
- [x] 2.3 Add `actions/checkout@v4` step.
- [x] 2.4 Add `docker/setup-buildx-action@v3` step.
- [x] 2.5 Add `docker/login-action@v3` step for ghcr.io using `GITHUB_TOKEN`.
- [x] 2.6 Source `ci/presets/${preset}.env` and propagate INSTALL_* variables.
- [x] 2.7 Compute version tag from `package.json`.
- [x] 2.8 Compute short SHA.
- [x] 2.9 Generate base Dockerfile via `GENERATE_ONLY=1 bash lib/install-base.sh`.
- [x] 2.10 Build `ai-base:latest` via `docker/build-push-action@v6` with GHA cache.
- [x] 2.11 Generate tool Dockerfile via `bash lib/install-${tool}.sh` (builds locally).
- [x] 2.12 Smoke test the resulting image.
- [x] 2.13 Tag with 3 schemes (rolling, sha, version) and push to ghcr.io.
- [x] 2.14 Validate YAML syntax.

## 3. Caller workflow (`build-opencode.yml`)

- [x] 3.1 Create `.github/workflows/build-opencode.yml`.
- [x] 3.2 Configure `on.push.branches: [master]` with `paths:` filter.
- [x] 3.3 Configure `on.workflow_dispatch.inputs.preset` as optional string with choices.
- [x] 3.4 Add a `matrix` job that computes preset list (single if input provided, both if not).
- [x] 3.5 Invoke `build-image.yml` with `secrets: inherit`.
- [x] 3.6 Validate YAML syntax.

## 4. Cleanup obsolete CI

- [x] 4.1 Remove `build-base` job from `.github/workflows/ci.yml`.
- [x] 4.2 Remove `build-base-addons` job from `.github/workflows/ci.yml`.
- [x] 4.3 Remove `build-tools` job from `.github/workflows/ci.yml`.
- [x] 4.4 Keep the `lint` job intact. Add header comment explaining the scope reduction.

## 5. ai-run registry switch

- [x] 5.1 Read current `bin/ai-run` AI_IMAGE_SOURCE logic.
- [x] 5.2 Add `AI_IMAGE_REGISTRY` env var with default `ghcr.io/nano-step/ai-opencode`.
- [x] 5.3 Add `AI_IMAGE_TAG` env var with default `base`.
- [x] 5.4 Change IMAGE URL to `${AI_IMAGE_REGISTRY}:${AI_IMAGE_TAG}` when registry mode.
- [x] 5.5 Update help text to document the new env vars.
- [x] 5.6 Validate shell syntax: `bash -n bin/ai-run`.

## 6. Documentation

- [x] 6.1 Add "Pre-built Images from ghcr.io" section to `README.md`.
- [x] 6.2 CHANGELOG handled by `publish-stable.yml` auto-generator from conventional commit messages.
- [x] 6.3 Verify `AGENTS.md` already documents the preset policy under "Adding a New Tool > Kind B".

## 7. First publish (POST-MERGE actions)

> These steps cannot be executed during local implementation. Tracked here for
> maintainer reference. Not blockers for archive.

- [ ] 7.1 After PR merge to master, trigger `build-opencode.yml` via `workflow_dispatch`.
- [ ] 7.2 Verify build succeeds for both presets in Actions UI.
- [ ] 7.3 Confirm images appear under `Packages` on the GitHub repo page.
- [ ] 7.4 Test pull from a clean machine.
- [ ] 7.5 Test `AI_IMAGE_SOURCE=registry ai-run opencode --help` end-to-end.

## 8. Verification

- [x] 8.1 Validate the OpenSpec change with `--strict --no-interactive`.
- [x] 8.2 Run the existing test suite: `npm test`.
- [x] 8.3 Run `bash -n` on every shell script touched.
- [ ] 8.4 Manually inspect first published image's `docker history`. **(post-merge)**
- [ ] 8.5 Verify `INSTALL_PLAYWRIGHT_HOST=1` actually skipped Chromium download. **(post-merge)**
