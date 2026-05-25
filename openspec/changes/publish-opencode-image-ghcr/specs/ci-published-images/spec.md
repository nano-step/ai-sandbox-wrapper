## ADDED Requirements

### Requirement: Preset definition format
The repository SHALL define each published image preset as an `.env` file under `ci/presets/<preset>.env` containing one `INSTALL_<FLAG>=<value>` per line. Each preset file MUST be self-contained — the build pipeline MUST NOT layer or merge preset files. Adding a new preset requires creating a new file; adding a new flag to an existing preset requires editing exactly one `.env` file.

#### Scenario: Reading a preset
- **WHEN** the build pipeline needs the flag values for preset `<name>`
- **THEN** it SHALL read `ci/presets/<name>.env`
- **AND** every line matching `INSTALL_<FLAG>=<value>` SHALL be exported as an environment variable
- **AND** lines starting with `#` or empty lines SHALL be ignored

#### Scenario: Base preset contents
- **WHEN** `ci/presets/base.env` is read
- **THEN** the following flags SHALL be set to `1`:
  - `INSTALL_SPEC_KIT`
  - `INSTALL_UX_UI_PROMAX`
  - `INSTALL_OPENSPEC`
  - `INSTALL_RTK`
  - `INSTALL_PUP`
  - `INSTALL_ACLI`
  - `INSTALL_GO`
  - `INSTALL_CHROME_DEVTOOLS_MCP`
  - `INSTALL_PLAYWRIGHT_MCP`
  - `INSTALL_PLAYWRIGHT_HOST`
- **AND** the following flags SHALL be set to `0`:
  - `INSTALL_OD_HELPERS`
  - `INSTALL_PLAYWRIGHT`
  - `INSTALL_RUBY`

#### Scenario: Full preset contents
- **WHEN** `ci/presets/full.env` is read
- **THEN** every flag set in `base.env` to `1` SHALL also be set to `1` in `full.env`
- **AND** the following additional flags SHALL be set to `1`:
  - `INSTALL_OD_HELPERS`
  - `INSTALL_PLAYWRIGHT`
- **AND** `INSTALL_RUBY` SHALL be set to `0`

### Requirement: Reusable build workflow
The repository SHALL provide a reusable GitHub Actions workflow at `.github/workflows/build-image.yml` that accepts `tool` (string, required) and `preset` (string, required) as `workflow_call` inputs and builds the image `ai-<tool>` using the flags from `ci/presets/<preset>.env`.

#### Scenario: Workflow invocation
- **WHEN** a caller workflow invokes `build-image.yml` with `tool: opencode, preset: base`
- **THEN** the reusable workflow SHALL:
  - Check out the repository at the caller's ref
  - Set up Docker Buildx with GitHub Actions cache
  - Log in to `ghcr.io` using the workflow's `GITHUB_TOKEN`
  - Source `ci/presets/base.env` into the environment
  - Run `bash lib/install-base.sh` to build `ai-base:latest`
  - Run `bash lib/install-opencode.sh` to build `ai-opencode:latest`
  - Tag and push the resulting image to `ghcr.io/<owner>/ai-opencode` with the tags defined below

#### Scenario: Required permissions
- **WHEN** `build-image.yml` is invoked
- **THEN** the job SHALL declare `permissions: { contents: read, packages: write }` to allow ghcr.io push

#### Scenario: Build failure surfaces upstream
- **WHEN** any step in `build-image.yml` exits non-zero
- **THEN** the caller workflow SHALL fail
- **AND** no image SHALL be pushed to ghcr.io

### Requirement: Caller workflow for opencode
The repository SHALL provide a caller workflow at `.github/workflows/build-opencode.yml` that invokes `build-image.yml` for the `opencode` tool against every preset on push to `master` (with changes filter) and on manual dispatch.

#### Scenario: Push trigger with relevant changes
- **WHEN** a commit is pushed to `master` that modifies any of:
  - `lib/install-base.sh`
  - `lib/install-opencode.sh`
  - `skills/rtk/**`, `skills/rtk-setup/**`, `skills/dd-pup/**`
  - `scripts/od-status`, `scripts/od-health`
  - `ci/presets/*.env`
  - `.github/workflows/build-image.yml`
  - `.github/workflows/build-opencode.yml`
  - `dockerfiles/opencode/**`, `dockerfiles/base/**`
- **THEN** `build-opencode.yml` SHALL run automatically
- **AND** it SHALL invoke `build-image.yml` once per preset in `[base, full]`

#### Scenario: Push trigger with irrelevant changes
- **WHEN** a commit is pushed to `master` that does NOT modify any of the listed paths
- **THEN** `build-opencode.yml` SHALL NOT run

#### Scenario: Manual dispatch
- **WHEN** a maintainer invokes `build-opencode.yml` via `workflow_dispatch`
- **THEN** the workflow SHALL accept an optional `preset` input
- **AND** if `preset` is provided, only that preset SHALL be built
- **AND** if `preset` is omitted, both `base` and `full` SHALL be built

### Requirement: Image tagging scheme
Every push to ghcr.io SHALL apply three tags per preset: the rolling preset name, an immutable SHA tag, and a semver tag derived from `package.json`.

#### Scenario: Tags for a successful build
- **WHEN** `build-image.yml` successfully builds `ai-opencode` for preset `base` at commit SHA `abc123def` with `package.json` version `5.0.0`
- **THEN** the image SHALL be pushed with all of these tags:
  - `ghcr.io/<owner>/ai-opencode:base`
  - `ghcr.io/<owner>/ai-opencode:base-sha-abc123d`
  - `ghcr.io/<owner>/ai-opencode:base-v5.0.0`

#### Scenario: Tag immutability for SHA and semver
- **WHEN** a previously-published `:base-sha-<short>` or `:base-v<x.y.z>` tag is encountered
- **THEN** the workflow MAY overwrite it (registry has no built-in immutability)
- **AND** the maintainer SHOULD avoid re-pushing the same SHA tag

### Requirement: Build cache reuse
The build workflow SHALL use GitHub Actions cache (`type=gha`) to share Docker layers across runs.

#### Scenario: Cold cache build
- **WHEN** `build-image.yml` runs for the first time after a cache eviction
- **THEN** the full image SHALL be built from scratch (10-20 minutes acceptable)
- **AND** all intermediate layers SHALL be exported to the cache with `mode=max`

#### Scenario: Warm cache build
- **WHEN** `build-image.yml` runs on a commit that did not modify `lib/install-base.sh`
- **THEN** the `ai-base:latest` layers SHALL be restored from cache
- **AND** the build SHALL complete in approximately 3-5 minutes

### Requirement: Policy for adding new INSTALL flags
A contributor adding a new `INSTALL_<FLAG>` to `lib/install-base.sh` MUST update `ci/presets/<preset>.env` only after consulting the user about which preset(s) should include the flag. The `AGENTS.md` documentation SHALL describe this policy.

#### Scenario: Adding a new flag
- **WHEN** a contributor adds `INSTALL_FOO=1` block to `lib/install-base.sh`
- **THEN** the contributor SHALL ask the user whether `FOO` belongs in `base`, `full`, both, or neither
- **AND** based on the answer, edit the corresponding `ci/presets/<preset>.env` file(s)
- **AND** never silently add the flag to a preset

#### Scenario: AGENTS.md documents the policy
- **WHEN** an AI agent reads `AGENTS.md` under "Adding a New Tool > Kind B"
- **THEN** the agent SHALL find a step that explicitly instructs asking the user before updating preset files

### Requirement: Out-of-scope items are deferred
This change SHALL NOT include multi-architecture builds, cosign signing, SBOM generation, or building other tool images (`ai-claude`, `ai-amp`). Those are deferred to future changes.

#### Scenario: Build target is amd64 only
- **WHEN** `build-image.yml` runs
- **THEN** the image SHALL be built for `linux/amd64` only
- **AND** the workflow SHALL NOT invoke QEMU emulation

#### Scenario: No image signing in this change
- **WHEN** an image is pushed to ghcr.io by this workflow
- **THEN** no cosign signature SHALL be attached
- **AND** no provenance attestation SHALL be generated

### Requirement: ai-run uses ghcr.io by default
The `bin/ai-run` script SHALL default to pulling from `ghcr.io/nano-step/ai-opencode:base` when `AI_IMAGE_SOURCE=registry` is set. Users SHALL be able to override both the registry and the tag via `AI_IMAGE_REGISTRY` and `AI_IMAGE_TAG` environment variables.

#### Scenario: Default registry pull
- **WHEN** a user runs `AI_IMAGE_SOURCE=registry ai-run opencode` without overrides
- **THEN** `ai-run` SHALL pull `ghcr.io/nano-step/ai-opencode:base`

#### Scenario: Registry override
- **WHEN** a user sets `AI_IMAGE_REGISTRY=registry.gitlab.com/kokorolee/ai-sandbox-wrapper/ai-sandbox`
- **AND** runs `AI_IMAGE_SOURCE=registry ai-run opencode`
- **THEN** `ai-run` SHALL pull from the overridden registry path

#### Scenario: Tag override
- **WHEN** a user sets `AI_IMAGE_TAG=full`
- **AND** runs `AI_IMAGE_SOURCE=registry ai-run opencode`
- **THEN** `ai-run` SHALL pull `ghcr.io/nano-step/ai-opencode:full`

#### Scenario: Local image source unchanged
- **WHEN** `AI_IMAGE_SOURCE` is unset or set to `local`
- **THEN** `ai-run` SHALL continue to use the locally-built `ai-sandbox:latest` image
- **AND** the registry override env vars SHALL be ignored
