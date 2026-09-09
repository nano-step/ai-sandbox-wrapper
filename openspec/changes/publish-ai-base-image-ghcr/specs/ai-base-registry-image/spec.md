## ADDED Requirements

### Requirement: ai-base registry publication

The CI pipeline SHALL publish `ai-base` Docker images to `ghcr.io/nano-step/ai-base` after building `ai-base:latest` locally. Each preset defined in `ci/presets/*.env` SHALL produce a distinct image with three tags: a rolling preset tag, a per-commit SHA tag, and a semver tag derived from `package.json`.

#### Scenario: Publish for base preset
- **WHEN** the `Build ai-base` step in `.github/workflows/build-image.yml` completes for preset `base` at commit SHA `abc123def4567` with `package.json` version `5.5.0`
- **THEN** the `Push ai-base` step SHALL push the resulting image to all three of these tags:
  - `ghcr.io/nano-step/ai-base:base`
  - `ghcr.io/nano-step/ai-base:base-sha-abc123d`
  - `ghcr.io/nano-step/ai-base:base-v5.5.0`

#### Scenario: Publish for full preset
- **WHEN** the `Build ai-base` step completes for preset `full` at commit SHA `abc123def4567` with `package.json` version `5.5.0`
- **THEN** the `Push ai-base` step SHALL push the resulting image to all three of these tags:
  - `ghcr.io/nano-step/ai-base:full`
  - `ghcr.io/nano-step/ai-base:full-sha-abc123d`
  - `ghcr.io/nano-step/ai-base:full-v5.5.0`

#### Scenario: Push failure does not break tool image publish
- **WHEN** the `Push ai-base` step fails (e.g., transient ghcr.io outage)
- **THEN** the step SHALL exit non-zero
- **AND** the step SHALL use `continue-on-error: true` with a `::warning::` annotation
- **AND** the subsequent `Tag & push to ghcr.io` step (which pushes `ai-<tool>:latest`) SHALL still execute

#### Scenario: Push runs after tool build, before smoke test
- **WHEN** the `.github/workflows/build-image.yml` reusable workflow runs
- **THEN** the `Push ai-base` step SHALL be inserted between the `Generate tool Dockerfile and build` step and the `Smoke test` step
- **AND** a broken `ai-base:latest` SHALL be caught by the smoke test before being published (i.e., if smoke test fails, the base push has already happened but the tool push is skipped)

### Requirement: Local helper script for ai-base

A shell helper script at `lib/ensure-ai-base.sh` SHALL be provided that ensures a local `ai-base:<preset>` image is available before any tool install script invokes `docker build`. The helper SHALL be idempotent and respect user-controllable mode env vars.

#### Scenario: Local mode with existing image
- **WHEN** the helper is invoked with `<preset>=base` and `BASE_IMAGE_MODE=local` and `docker image inspect ai-base:base` exits 0
- **THEN** the helper SHALL exit 0
- **AND** SHALL emit a log line `[ensure-ai-base] Using local ai-base:base (BASE_IMAGE_MODE=local)`
- **AND** SHALL NOT invoke `docker pull`
- **AND** SHALL NOT retag any image

#### Scenario: Local mode with missing image
- **WHEN** the helper is invoked with `BASE_IMAGE_MODE=local` and `docker image inspect ai-base:base` exits non-zero
- **THEN** the helper SHALL exit 1
- **AND** SHALL emit an error message naming the missing tag and instructing the user to run `bash lib/install-base.sh` to build locally

#### Scenario: Registry mode successful pull
- **WHEN** the helper is invoked with `BASE_IMAGE_MODE=registry` and `docker image inspect ai-base:base` exits non-zero
- **AND** `docker pull ghcr.io/nano-step/ai-base:base` exits 0
- **THEN** the helper SHALL exit 0
- **AND** SHALL emit a log line `[ensure-ai-base] Pulled ghcr.io/nano-step/ai-base:base (sha256:...)`

#### Scenario: Registry mode pull failure with fallback enabled
- **WHEN** the helper is invoked with `BASE_IMAGE_MODE=registry` and `BASE_IMAGE_ALLOW_LOCAL_BUILD=1` (default)
- **AND** `docker pull ghcr.io/nano-step/ai-base:base` exits non-zero
- **THEN** the helper SHALL emit a `::warning::` log line
- **AND** SHALL invoke `bash lib/install-base.sh` to build `ai-base:latest` locally
- **AND** SHALL exit 0 if the local build succeeds

#### Scenario: Registry mode pull failure with fallback disabled
- **WHEN** the helper is invoked with `BASE_IMAGE_MODE=registry` and `BASE_IMAGE_ALLOW_LOCAL_BUILD=0`
- **AND** `docker pull ghcr.io/nano-step/ai-base:base` exits non-zero
- **THEN** the helper SHALL exit 1
- **AND** SHALL emit a recoverable error message naming the failed tag and instructing the user to either verify network connectivity or set `BASE_IMAGE_ALLOW_LOCAL_BUILD=1`

#### Scenario: Custom registry and tag override
- **WHEN** the helper is invoked with `AI_IMAGE_BASE_REGISTRY=ghcr.io/some-other-org/ai-base-fork` and `AI_IMAGE_BASE_TAG=base-sha-deadbee`
- **AND** the helper is in registry mode and the local tag is missing
- **THEN** the helper SHALL `docker pull ghcr.io/some-other-org/ai-base-fork:base-sha-deadbee` instead of the default `ghcr.io/nano-step/ai-base:base`

#### Scenario: First-run migration notice
- **WHEN** the helper is invoked and the marker file `~/.ai-sandbox/.ai-base-from-registry-acked` does not exist
- **THEN** the helper SHALL emit a one-time notice explaining the registry-based install behavior
- **AND** SHALL create the marker file
- **AND** subsequent invocations SHALL NOT emit the notice

### Requirement: Tool Dockerfile FROM references explicit preset tag

Every tool install script in `lib/install-<tool>.sh` (where `<tool>` ∈ {claude, codex, aider, amp, auggie, codebuddy, droid, gemini, jules, qoder, qwen, shai, opencode} and also `lib/install-tool.sh`) SHALL generate a Dockerfile whose `FROM` line references the preset tag explicitly, not `:latest`.

#### Scenario: Generated Dockerfile FROM line
- **WHEN** any of the 14 tool install scripts (`lib/install-claude.sh`, `lib/install-codex.sh`, `lib/install-aider.sh`, `lib/install-amp.sh`, `lib/install-auggie.sh`, `lib/install-codebuddy.sh`, `lib/install-droid.sh`, `lib/install-gemini.sh`, `lib/install-jules.sh`, `lib/install-qoder.sh`, `lib/install-qwen.sh`, `lib/install-shai.sh`, `lib/install-opencode.sh`, `lib/install-tool.sh`) generates `dockerfiles/<tool>/Dockerfile`
- **THEN** the generated Dockerfile SHALL contain a `FROM ai-base:${BASE_IMAGE_PRESET:-base}` line
- **AND** SHALL NOT contain a `FROM ai-base:latest` line

#### Scenario: opencode two-branch Dockerfile
- **WHEN** `lib/install-opencode.sh` generates the Dockerfile in the `OPENCODE_VERSION` branch
- **AND** in the default branch (no `OPENCODE_VERSION` set)
- **THEN** BOTH generated Dockerfiles SHALL contain `FROM ai-base:${BASE_IMAGE_PRESET:-base}`
- **AND** NEITHER generated Dockerfile SHALL contain `FROM ai-base:latest`

#### Scenario: kilo is out of scope
- **WHEN** `lib/install-kilo.sh` generates its Dockerfile
- **THEN** it SHALL continue to use `FROM node:22-slim` (unchanged by this change)

### Requirement: Tool install scripts invoke helper before docker build

Every tool install script SHALL invoke `bash "$(dirname "$0")/ensure-ai-base.sh" "${BASE_IMAGE_PRESET:-base}"` immediately before the `docker build ... -t "ai-$TOOL:latest"` line.

#### Scenario: Helper invocation location
- **WHEN** any of the 14 tool install scripts runs
- **THEN** the line invoking the helper SHALL appear before the `docker build` line
- **AND** the helper SHALL be invoked with the value of `$BASE_IMAGE_PRESET` (defaulting to `base` if unset)
- **AND** the helper SHALL resolve its own path via `$(dirname "$0")` (not a hardcoded `lib/` path)

#### Scenario: Helper exits non-zero aborts tool install
- **WHEN** the helper exits 1 (e.g., local-mode with missing image, or registry-mode with fallback disabled and pull failure)
- **THEN** the tool install script's `set -e` SHALL cause it to abort
- **AND** no `docker build` SHALL be attempted

### Requirement: setup.sh exports BASE_IMAGE_PRESET

The `setup.sh` interactive installer SHALL export `BASE_IMAGE_PRESET=base` in the block where it exports `INSTALL_*` flags (around line 672).

#### Scenario: Default preset export
- **WHEN** `setup.sh` exports its environment before invoking `lib/install-<tool>.sh`
- **THEN** it SHALL include `export BASE_IMAGE_PRESET=base` in the same export block as the `INSTALL_*` flags
- **AND** users SHALL be able to override by running `BASE_IMAGE_PRESET=full bash setup.sh`

### Requirement: README documents the new ai-base UX

The `README.md` SHALL include a "Pull base image from ghcr.io" section immediately after the existing "Pre-built Images from ghcr.io" section.

#### Scenario: README content requirements
- **WHEN** the README's new section is read by a new user
- **THEN** it SHALL contain:
  - A `BASE_IMAGE_PRESET=base bash lib/install-<tool>.sh` example showing the new fast path
  - A SHA-pin rollback example: `AI_IMAGE_BASE_TAG=base-sha-<old-sha> bash lib/install-<tool>.sh`
  - An offline fallback example: `BASE_IMAGE_ALLOW_LOCAL_BUILD=1 bash lib/install-<tool>.sh`
  - A contributor-workflow note: "If you are iterating on `lib/install-base.sh`, set `BASE_IMAGE_MODE=local`"
  - A leading sentence: "If you only need the registry tool image, you do not need to pull `ai-base` separately"
- **AND** it SHALL NOT advertise a `--pull-base` flag on `bin/ai-run` (which does not exist after this change)

### Requirement: Acceptance tests for the change

The change's `tasks.md` SHALL include at least four verifiable acceptance tests that prove the user-facing goal is achieved.

#### Scenario: Acceptance test — pull from registry
- **WHEN** a clean machine (no local `ai-*` images) runs `docker pull ghcr.io/nano-step/ai-base:base`
- **THEN** the command SHALL exit 0
- **AND** the resulting image SHALL be non-empty (verified via `docker image inspect` returning non-zero `Size`)
- **AND** the total time SHALL be under 60 seconds on a 100 Mbps connection

#### Scenario: Acceptance test — clean install under 2 minutes
- **WHEN** a clean machine (no local `ai-*` images) runs `BASE_IMAGE_PRESET=base bash lib/install-claude.sh`
- **THEN** the entire command SHALL complete in under 180 seconds wall clock
- **AND** `docker image inspect ai-claude:latest` SHALL exit 0
- **AND** `docker run --rm ai-claude:latest --version` SHALL exit 0 (or with the documented smoke-test tolerance)

#### Scenario: Acceptance test — contributor local-mode preserved
- **WHEN** a contributor runs `bash lib/install-claude.sh` with `BASE_IMAGE_MODE=local` set (default) and a local `ai-base:latest` built from `bash lib/install-base.sh`
- **THEN** the helper SHALL emit `[ensure-ai-base] Using local ai-base:base (BASE_IMAGE_MODE=local)`
- **AND** SHALL NOT invoke `docker pull`
- **AND** the resulting `ai-claude:latest` SHALL be built atop the contributor's local `ai-base:latest`

#### Scenario: Acceptance test — SHA-pin rollback
- **WHEN** a user runs `AI_IMAGE_BASE_TAG=base-sha-<known-good-sha> bash lib/install-claude.sh` after a known-bad `:base` push
- **THEN** the helper SHALL pull `ghcr.io/nano-step/ai-base:base-sha-<known-good-sha>`
- **AND** the tool install SHALL succeed

### Requirement: Out-of-scope items remain deferred

This change SHALL NOT include multi-architecture builds, cosign signing, SBOM generation, ghcr.io SHA-tag retention cleanup, modifying the `bin/ai-run` runtime launcher, modifying `lib/build-sandbox.sh` for the unified `ai-sandbox:latest` flow, or building other tool images on CI.

#### Scenario: No multi-arch build
- **WHEN** the `Push ai-base` step runs
- **THEN** it SHALL build and push `linux/amd64` only
- **AND** it SHALL NOT invoke QEMU emulation

#### Scenario: No image signing
- **WHEN** an image is pushed to ghcr.io by this change's workflow
- **THEN** no cosign signature SHALL be attached
- **AND** no SBOM SHALL be generated

#### Scenario: bin/ai-run unchanged
- **WHEN** the change is complete
- **THEN** `bin/ai-run` SHALL NOT contain any of: `AI_IMAGE_BASE_REGISTRY`, `AI_IMAGE_BASE_TAG`, `AI_IMAGE_BASE_MAX_AGE_DAYS`, `--pull-base`, `--no-pull-base`
- **AND** `grep -n "Dockerfile\|dockerfiles" bin/ai-run` in executable code SHALL continue to return 0 hits

#### Scenario: ai-sandbox:latest path unchanged
- **WHEN** the change is complete
- **THEN** `lib/build-sandbox.sh` SHALL continue to inline the base Dockerfile content via `BASE_CONTENT=$(cat "$BASE_DOCKERFILE")`
- **AND** SHALL NOT pull from `ghcr.io/nano-step/ai-base:*`

#### Scenario: kilo install script unchanged
- **WHEN** the change is complete
- **THEN** `lib/install-kilo.sh` SHALL continue to use `FROM node:22-slim`
- **AND** SHALL NOT invoke `lib/ensure-ai-base.sh`
