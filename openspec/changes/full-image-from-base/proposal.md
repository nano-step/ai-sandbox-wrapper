# Proposal: full-image-from-base

## Why

The `:full` preset is a strict superset of `:base` — it differs only by 2 flags (`INSTALL_OD_HELPERS=1`, `INSTALL_PLAYWRIGHT=1`). Currently both presets rebuild `ai-base` and the shared tool layer from scratch in separate CI jobs, wasting ~70-80% of `:full`'s build time on work that was already done by the `:base` job.

## What Changes

- **`lib/install-opencode.sh`**: Add a `FROM_IMAGE` mode — when `FROM_IMAGE` env var is set, generate a Dockerfile that uses the provided image as base (`FROM $FROM_IMAGE`) instead of `FROM ai-base:latest`, then installs only the diff flags on top.
- **`ci/presets/full.env`**: Add `FROM_IMAGE_PRESET=base` to declare that `:full` layers on top of `:base`.
- **`.github/workflows/build-image.yml`**: When `FROM_IMAGE_PRESET` is set in the preset env, pull the corresponding already-published image (e.g. `ghcr.io/nano-step/ai-opencode:base`) and use it as the build base instead of rebuilding from `ai-base`.
- **`.github/workflows/build-opencode.yml`**: `build-full` continues to `needs: build-base` (already in place) — ensures `:base` is published before `:full` pulls it.

## Capabilities

**New Capabilities**: none — this is a CI build optimization, no user-facing behavior changes.

**Modified Capabilities**: none — image contents of `:base` and `:full` are identical before and after. Only the build path changes.

## Impact

- **`lib/install-opencode.sh`**: New `FROM_IMAGE` env var branch in Dockerfile generation.
- **`ci/presets/full.env`**: New `FROM_IMAGE_PRESET=base` line.
- **`.github/workflows/build-image.yml`**: Logic to detect `FROM_IMAGE_PRESET`, resolve registry image URL, pass it to `install-opencode.sh`.
- **No user-facing API changes**: `AI_IMAGE_SOURCE`, `AI_IMAGE_TAG`, `AI_IMAGE_REGISTRY` env vars unchanged.
- **Risk**: If `:base` publish fails and `:full` tries to pull it, `:full` will also fail. This is acceptable — `needs: build-base` + `fail-fast: true` already gates this. Old behavior (rebuild from scratch) can be restored by removing `FROM_IMAGE_PRESET` from `full.env`.
- **Local builds**: Unaffected. `docker build` locally still uses `FROM ai-base:latest` (no `FROM_IMAGE` set).
