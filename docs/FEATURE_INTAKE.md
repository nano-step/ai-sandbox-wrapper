# Feature Intake — ai-sandbox-wrapper

Use this checklist when a new request arrives. Complete it before creating the issue.

## 1. Classify the request

Answer these questions:

- [ ] Is this touching a **hard gate**?
  - Docker security (CAP_DROP, non-root, volume mounts)
  - SSH key handling
  - Network access to host services
  - Container permissions
  - → **If yes → high-risk lane, stop and review**

- [ ] Does this change behavior users depend on?
  - → If yes → at minimum `normal` lane

- [ ] Is this a typo, comment, or single-line config with no behavior impact?
  - → `tiny` lane

## 2. Pick a lane

| Signal | Lane |
|--------|------|
| Hard gate touched | `high-risk` |
| New tool, flag, or behavior change | `normal` |
| Docs, typo, dep bump | `tiny` |

## 3. Create the issue

Use the story template: [`docs/templates/story.md`](templates/story.md)

Apply labels:
- `lane:<tiny|normal|high-risk>`
- `change-type:<feat|fix|refactor|docs|chore|security>`

## 4. Kick off the flow

| Lane | Next step |
|------|-----------|
| tiny | Implement directly, quick validate, PR |
| normal | `openspec new change "<name>"` → implement → validate → PR |
| high-risk | Same as normal + security review + extra sign-off |
