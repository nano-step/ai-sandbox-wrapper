## Context

`ai-run` executes tools in containerized environments where native Node modules may be missing or built for the wrong architecture. For nano-brain, this appears as tree-sitter/native binding failures during `npx nano-brain` commands.

## Goals / Non-Goals

**Goals:**
- Detect nano-brain runtime dependency issues before or during launch
- Auto-run safe repair steps for known failures
- Preserve deterministic behavior with explicit logs and opt-out controls

**Non-Goals:**
- Generic repair for every npm package ecosystem failure
- Automatic mutation of unrelated user projects

## Decisions

### Add targeted nano-brain preflight hook
**Decision**: Add a guarded preflight path that runs only when command target is nano-brain.
**Rationale**: Avoid overhead and side effects for unrelated tools.

### Implement known-error signature matching
**Decision**: Match known stderr patterns (missing native binding/tree-sitter architecture mismatch) and execute repair flow.
**Rationale**: Reliable detection for the real failure mode with minimal false positives.

### Provide opt-out and clear status output
**Decision**: Support opt-out via env/flag and print each repair action with success/failure summary.
**Rationale**: Users need control in CI and confidence in what changed.

## Risks / Trade-offs

- **Startup delay** when preflight executes repairs.
- **Partial repair outcomes** if network/package registry unavailable.
- **Mitigation**: Fail with actionable next steps and explicit command hints.