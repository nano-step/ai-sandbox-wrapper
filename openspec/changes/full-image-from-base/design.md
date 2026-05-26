## Context

Currently `build-opencode.yml` runs two reusable workflow calls: `build-base` (preset `base`) and `build-full` (preset `full`). Both invoke `build-image.yml` which independently:
1. Builds `ai-base` from scratch
2. Generates `dockerfiles/opencode/Dockerfile` (`FROM ai-base:latest`)
3. Builds `ai-opencode` on top

Since `full.env` is a strict superset of `base.env` (identical flags + 2 extras: `INSTALL_OD_HELPERS=1`, `INSTALL_PLAYWRIGHT=1`), the `:full` job rebuilds everything `:base` already built — wasting ~70-80% of its runtime.

After the `needs: build-base` fix already landed, `:full` runs sequentially after `:base`. The GHA cache partially helps for `ai-base`, but the tool layer (opencode binary + preset-specific installs) still rebuilds from scratch.

## Goals / Non-Goals

**Goals:**
- `:full` builds only the diff on top of the already-published `:base` image
- Cold build time for `:full` drops from ~15-20 min to ~3-5 min
- Local `docker build` workflow is unchanged (no `FROM_IMAGE` set by default)
- Easy rollback: remove `FROM_IMAGE_PRESET` from `full.env` → restores original behavior

**Non-Goals:**
- Changing image contents of `:base` or `:full`
- Optimizing `:base` build time (already well-cached)
- Supporting arbitrary multi-hop chains (`:full` → `:fuller`) — not needed

## Decisions

### D1: Where the "pull from registry" logic lives — workflow vs install script

**Decision**: Logic lives in `build-image.yml`. When `FROM_IMAGE_PRESET` is set in the preset env, the workflow:
1. Constructs the source image URL (`$IMAGE:$FROM_IMAGE_PRESET`)
2. Pulls it and re-tags as `ai-base:latest` locally
3. Proceeds with the existing `Generate tool Dockerfile` + `Build tool image` steps unchanged

The install script (`install-opencode.sh`) does **not** change.

**Rationale**: The install script generates `FROM ai-base:latest` — which is correct regardless of whether `ai-base:latest` came from a fresh build or a registry pull. Keeping the logic in the workflow avoids coupling the install script to CI concerns. The `ai-base:latest` local tag becomes the abstraction boundary.

**Alternatives considered**:
- *`FROM_IMAGE` env var in install script*: Generates `FROM $FROM_IMAGE` directly. More explicit but leaks CI registry URLs into a script also used for local builds. Rejected.
- *Separate `install-full.sh`*: Duplicates the install script just for a 2-flag difference. Rejected.

### D2: Skip `Build ai-base` step when pulling from registry

**Decision**: Add a conditional in the workflow: if `FROM_IMAGE_PRESET` is set, skip `Generate base Dockerfile` + `Build ai-base` steps and instead run a `Pull base image` step that pulls `$IMAGE:$FROM_IMAGE_PRESET` and re-tags it as `ai-base:latest`.

**Rationale**: Skipping the base build entirely (not just cache-hitting) is the point of the optimization. The re-tag to `ai-base:latest` preserves the existing `FROM ai-base:latest` contract in tool Dockerfiles.

**Alternatives considered**:
- *Keep building ai-base but also pull*: Redundant work. Rejected.
- *Use `--build-arg BASE_IMAGE=...` in tool Dockerfile*: Requires modifying all tool Dockerfiles and install scripts. More invasive. Rejected.

### D3: `FROM_IMAGE_PRESET` declared in preset env file

**Decision**: Add `FROM_IMAGE_PRESET=base` to `full.env`. The workflow reads this after sourcing the preset file.

**Rationale**: Keeps the "what `:full` is based on" co-located with the rest of the preset definition. Self-documenting. Easy to remove for rollback.

## Risks / Trade-offs

- **`:base` must be published before `:full` pulls it** → Already gated by `needs: build-base` in `build-opencode.yml`. If `:base` push fails, `:full` will fail at the pull step with a clear error.
- **Registry pull adds ~30-60s latency** vs a cache hit on `ai-base` → Net win is still large (~10+ min saved on Playwright install alone).
- **Image digest drift**: `:full` will always be based on the `:base` published in the same run (by tag, not digest). Rolling tag is acceptable here — same-run consistency is guaranteed by `needs:`.
- **arm64 runner pulls amd64 image (or vice versa)**: Docker pull respects platform by default with `--platform`. Must ensure pull uses `${{ matrix.platform }}` flag.

## Migration Plan

1. Add `FROM_IMAGE_PRESET=base` to `ci/presets/full.env`
2. Add conditional logic in `build-image.yml` `build` job:
   - After `Load preset flags`: check if `FROM_IMAGE_PRESET` is set
   - If set: pull `$IMAGE:$FROM_IMAGE_PRESET` with `--platform ${{ matrix.platform }}`, re-tag as `ai-base:latest`, skip `Generate base Dockerfile` + `Build ai-base` steps
   - If not set: existing flow unchanged
3. Trigger manual workflow run to verify
4. **Rollback**: Remove `FROM_IMAGE_PRESET=base` from `full.env` → `:full` rebuilds from scratch as before

## Open Questions

- None. Approach is straightforward enough to implement directly.
