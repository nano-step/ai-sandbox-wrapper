## ADDED Requirements

### Requirement: Full preset builds on top of published base image
When a preset declares `FROM_IMAGE_PRESET`, the CI build SHALL pull the corresponding
already-published image and use it as the base instead of rebuilding from scratch.

#### Scenario: full preset skips ai-base rebuild
- **WHEN** `FROM_IMAGE_PRESET=base` is set in `ci/presets/full.env`
- **THEN** the `build-full` CI job SHALL pull `ghcr.io/nano-step/ai-opencode:base` for the correct platform, re-tag it as `ai-base:latest`, and skip the `Generate base Dockerfile` and `Build ai-base` steps

#### Scenario: base preset is unaffected
- **WHEN** `FROM_IMAGE_PRESET` is not set in `ci/presets/base.env`
- **THEN** the `build-base` CI job SHALL build `ai-base` from scratch as before

#### Scenario: platform-correct pull
- **WHEN** CI pulls the base image on an arm64 runner
- **THEN** the pulled image SHALL be `linux/arm64` (not `linux/amd64`)

#### Scenario: rollback by removing flag
- **WHEN** `FROM_IMAGE_PRESET` is removed from `full.env`
- **THEN** the `build-full` job SHALL rebuild from scratch with no other changes required
