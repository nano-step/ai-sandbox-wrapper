## 1. Preset config

- [x] 1.1 Add `FROM_IMAGE_PRESET=base` to `ci/presets/full.env`

## 2. Workflow logic

- [x] 2.1 In `build-image.yml` `build` job, after `Load preset flags` step: add a `Pull base image` step that checks if `FROM_IMAGE_PRESET` is set, pulls `$IMAGE:$FROM_IMAGE_PRESET` with `--platform ${{ matrix.platform }}`, and re-tags as `ai-base:latest`
- [x] 2.2 Make `Generate base Dockerfile` and `Build ai-base` steps conditional (`if: env.FROM_IMAGE_PRESET == ''`) so they are skipped when pulling from registry

## 3. Verification

- [x] 3.1 Run `npm test` (bash -n validation) — confirm no shell syntax errors
- [ ] 3.2 Trigger manual workflow run on branch, confirm `build-full` skips `Build ai-base` step and shows pull log instead
- [ ] 3.3 Confirm smoke test passes for both `:base` and `:full` in the triggered run
- [ ] 3.4 Confirm final `:full` image contents unchanged (opencode binary + all base flags + OD helpers + Playwright)
