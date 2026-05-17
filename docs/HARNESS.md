# Engineering Harness — ai-sandbox-wrapper

> Spec-driven, risk-classified workflow for shipping changes safely.

## Lanes

| Lane | When to use | Validation required |
|------|-------------|---------------------|
| **tiny** | Typos, docs, single-line config | Quick validate only |
| **normal** | Features, fixes, refactors | Quick validate + user-flow test |
| **high-risk** | Hard gates touched | All of normal + manual review + extra sign-off |

## Hard Gates (always high-risk lane)

Any change touching these areas **must** use the `high-risk` lane:

- Docker security (CAP_DROP, non-root user, volume mount scope)
- SSH key handling
- Network access to host services
- Container permissions

## Validation Ladder

### Quick validate
```bash
bash -n lib/*.sh && npm test
```
Run before every PR. Must pass with exit 0.

### User-flow test
```bash
# Build the image
bash lib/install-{tool}.sh

# Smoke test
docker run --rm ai-{tool}:latest {tool} --version
docker run --rm ai-{tool}:latest {tool} --help
```
Required for `normal` and `high-risk` lanes.

### High-risk extra gate
- Manual security review of diff
- Confirm CAP_DROP=ALL present in any new Dockerfile
- Confirm no host home directory mounts
- Second sign-off from maintainer before merge

## Change Flow

```
1. Intake       → Create GitHub issue, pick lane, apply labels
2. Propose      → openspec new change "<name>"  (skip for tiny)
3. Design       → Proposal → design.md → specs → tasks.md
4. Implement    → Work through tasks.md, keep issue updated
5. Validate     → Run validation ladder for your lane
6. PR           → Open PR, link issue, request review
7. Review       → Bot (gemini) + human sign-off
8. Archive      → openspec archive "<name>"  (skip for tiny)
9. Close        → Close issue, tag release if needed
```

## Issue Labels

### Lane labels
- `lane:tiny` — low-risk, no spec needed
- `lane:normal` — standard feature/fix flow
- `lane:high-risk` — hard gate touched, extra review required

### Change-type labels
- `change-type:feat` — new capability
- `change-type:fix` — bug fix
- `change-type:refactor` — internal restructure, no behavior change
- `change-type:docs` — documentation only
- `change-type:chore` — deps, CI, tooling
- `change-type:security` — security-focused change

### Status labels
- `status:in-progress`
- `status:blocked`
- `status:review`
- `status:done`

## Story Template

See [`docs/templates/story.md`](templates/story.md) for the standard issue body format.

## Evidence

All test outputs, screenshots, and decision logs go in [`docs/evidence/`](evidence/).
Name files: `YYYY-MM-DD-<change-name>-<artifact>.md`

## OpenSpec

This project uses OpenSpec for spec-driven changes.

```bash
# Start a new change
openspec new change "<name>"

# Validate before implementing
openspec validate "<name>" --strict --no-interactive

# Archive after merge
openspec archive "<name>"
```

## PR Bot

PR reviews are assisted by **gemini**. Ensure it's configured on the repo before opening PRs on `normal` and `high-risk` changes.

## Quick Reference

```bash
# Lint shell scripts
npm run lint

# Run tests
npm test

# Full quick validate
bash -n lib/*.sh && npm test

# Build a tool image
bash lib/install-<tool>.sh

# Validate shell syntax only
bash -n setup.sh
bash -n lib/*.sh
bash -n bin/ai-run
```
