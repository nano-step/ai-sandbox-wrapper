## Why

Running `npx nano-brain` in fresh or cross-architecture environments can fail with missing native bindings (for example tree-sitter related modules). Today users must manually diagnose and repair dependency issues, which breaks onboarding and automation.

## What Changes

- Add nano-brain preflight checks in runtime flow before executing nano-brain commands
- Detect known native-binding failures and trigger automatic repair steps
- Provide explicit logs showing what was repaired and what to run next on failure
- Add an opt-out flag/env for users who do not want auto-repair behavior

## Capabilities

### New Capabilities

- `nano-brain-runtime-health`: Preflight verification and guided repair for nano-brain runtime dependencies

### Modified Capabilities

- `container-runtime`: Integrates conditional nano-brain preflight and repair behavior

## Impact

- **Runtime entrypoint**: `bin/ai-run`
- **Support scripts**: `lib/` helper logic for detection/repair
- **Docs**: Update runtime usage and troubleshooting guidance
- **Risk**: Additional startup latency when preflight runs (mitigated by caching/sentinel checks)