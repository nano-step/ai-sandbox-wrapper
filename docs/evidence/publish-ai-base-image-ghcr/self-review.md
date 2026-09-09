# Self-Review: publish-ai-base-image-ghcr

**Date**: 2026-09-09
**Reviewer**: implementer (self)
**Scope**: complete diff on branch `feat/publish-ai-base-image-ghcr` vs `master`

## Diff stats

```
.github/workflows/build-image.yml | 31 +++++ (new Push ai-base step)
CHANGELOG-openspec.md             | 32 +++++ (new entry)
README.md                         | 51 +++++ (new "Pull base image" section)
lib/install-base.sh               | 18 +++++ (registry-mode opt-in)
setup.sh                          |  4 ++++ (BASE_IMAGE_PRESET export)
14 × lib/install-*.sh             |  4-6 ++ each (helper + FROM)
1 × lib/install-opencode.sh       |  6 ++-- (two FROM branches)

New files:
lib/ensure-ai-base.sh                                    (142 lines)
openspec/changes/publish-ai-base-image-ghcr/
  ├── proposal.md                                        (89 lines)
  ├── design.md                                          (180 lines)
  ├── tasks.md                                           (96 lines)
  └── specs/ai-base-registry-image/spec.md               (189 lines)
```

Total: ~1036 lines added across 20 tracked files + 6 new files.

## Staged-files audit (per Gate 4)

| File | Mine? | Notes |
|------|-------|-------|
| `.github/workflows/build-image.yml` | ✅ | New `Push ai-base to ghcr.io` step between tool build and smoke test |
| `CHANGELOG-openspec.md` | ✅ | New 2026-09-09 entry |
| `README.md` | ✅ | New `### Pull base image from ghcr.io` section (already had pre-existing edits — those are the user's, not mine) |
| `lib/install-base.sh` | ✅ | New registry-mode opt-in branch |
| `lib/install-{claude,codex,aider,amp,auggie,codebuddy,droid,gemini,jules,qoder,qwen,shai,tool}.sh` | ✅ | Helper invocation + FROM line change |
| `lib/install-opencode.sh` | ✅ | Helper + both FROM branches |
| `lib/install-kilo.sh` | ❌ (correctly NOT touched) | Uses `FROM node:22-slim` — out of scope per spec §Out-of-scope |
| `lib/ensure-ai-base.sh` | ✅ | New helper script |
| `setup.sh` | ✅ | New `BASE_IMAGE_PRESET` export |
| `bin/ai-run` | ❌ (correctly NOT touched) | Per Reviewer A's H1 finding, no Dockerfile-assembly path exists — changes would be dead-letter |
| `.github/workflows/build-opencode.yml` | ❌ (pre-existing user change, not mine) | User added schedule trigger (separate `schedule-image-rebuild` change) |
| `AGENTS.md` | ❌ (correctly NOT touched) | Reviewer B found the "Kind B" subheading the original proposal cited does not exist |
| `lib/build-sandbox.sh` | ❌ (correctly NOT touched) | Per Reviewer A's M3, out of scope — unified `ai-sandbox:latest` flow is separate change |

**No secrets, tokens, PII, or generated junk in the diff.**

## Spec ↔ implementation cross-check

| Spec requirement (ai-base-registry-image) | Implementation | Status |
|---|---|---|
| `ai-base` registry publication with 3 tags per preset | `Push ai-base to ghcr.io` step in build-image.yml line 120 | ✅ |
| `Push ai-base` runs after tool build, before smoke test | grep confirmed: line 105 → 120 → 143 | ✅ |
| `continue-on-error: true` on push step | Step config has `continue-on-error: true` + `::warning::` log line | ✅ |
| `lib/ensure-ai-base.sh` accepts `<preset>` as `$1` | line 26 of helper | ✅ |
| Local mode verifies local tag exists | `ensure_local()` function | ✅ |
| Registry mode pulls from `${AI_IMAGE_BASE_REGISTRY}:${AI_IMAGE_BASE_TAG}` | `ensure_registry()` function | ✅ |
| Fallback to local build on pull failure (`BASE_IMAGE_ALLOW_LOCAL_BUILD=1`) | Fallback branch in `ensure_registry()` | ✅ |
| Fail-closed on pull failure (`=0`) | Error branch in `ensure_registry()` | ✅ |
| First-run notice with marker file | `maybe_first_run_notice()` | ✅ |
| Tool Dockerfile `FROM ai-base:${BASE_IMAGE_PRESET:-base}` | 14 install scripts updated (15 heredoc sites including opencode's 2 branches) | ✅ |
| Tool install scripts invoke helper before docker build | 14 scripts; verified via grep | ✅ |
| `setup.sh` exports `BASE_IMAGE_PRESET=base` | setup.sh line 585 | ✅ |
| README documents new UX | README line 356+ | ✅ |
| Acceptance tests in tasks.md | tasks.md §8 | ✅ |
| Out-of-scope: no multi-arch, no signing, no `bin/ai-run` change, no `lib/build-sandbox.sh` change, kilo untouched | All verified | ✅ |

## Acceptance test status

| Test | Status |
|------|--------|
| 8.1 Pull from registry | ⏳ Post-merge (image not yet published) |
| 8.2 Clean install < 2 min | ⏳ Post-merge |
| 8.3 Contributor local-mode preserved | ✅ Verified locally 2026-09-09 (with fake alpine image tagged `ai-base:base`) |
| 8.4 SHA-pin rollback | ⏳ Post-merge |
| 8.5 CI fails fast on helper syntax error | ⏳ Post-merge |
| 8.6 CI push step ordering | ✅ Verified via grep |

## Open issues / risks identified during self-review

1. **First-run notice creates `~/.ai-sandbox/.ai-base-from-registry-acked` marker**: this is in the user's home directory, which could conflict with other tools using the same path. Mitigated by the dotted-prefix convention (hidden files for tool state). No further action.

2. **`lib/ensure-ai-base.sh` does not verify SHA after re-tag**: if `AI_IMAGE_BASE_TAG=base-sha-XXX` is set and the local `ai-base:base` exists with a different digest, the helper will pull and re-tag but won't warn that local was overwritten. Documented in design.md §D6 but not enforced. Acceptable for v1 — the rollback path is the override itself.

3. **No `git push` test on the branch yet**: branch is local only; PR creation is Gate 7.

4. **Pre-existing user changes are mixed into the working tree**: `bin/ai-run` and `.github/workflows/build-opencode.yml` were modified by the user before I started. These are NOT my changes; they should remain on master (or the user's separate PR). When I commit, I will only stage my files.

## Conclusion

No high/medium findings. All locally-verifiable acceptance tests pass. All spec requirements mapped to implementation. The 4 post-merge tests (8.1, 8.2, 8.4, 8.5) require the registry image to be published, which only happens after PR merge → first CI run.

**Gate 4 status**: PASS. Ready for Gate 5 (independent subagent review).
