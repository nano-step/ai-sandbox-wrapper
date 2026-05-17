# Evidence Directory

This directory stores artifacts from completed changes:
test outputs, screenshots, decision logs.

## Naming convention

```
YYYY-MM-DD-<change-name>-<artifact-type>.md
```

Examples:
- `2026-05-17-add-gemini-tool-smoke-test.md`
- `2026-05-17-refactor-port-mapping-decision.md`
- `2026-05-17-fix-ssh-leak-security-review.md`

## Artifact types

| Type | Contents |
|------|----------|
| `smoke-test` | Docker run output, exit codes |
| `decision` | Tradeoffs considered, choice made, reasoning |
| `security-review` | Manual review notes for high-risk changes |
| `test-output` | npm test / shellcheck output |
| `screenshot` | UI/output screenshots (attach as image) |
