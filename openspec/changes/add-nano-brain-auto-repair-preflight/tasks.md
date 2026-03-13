## 1. Runtime Detection and Repair

- [x] 1.1 Add nano-brain command detection in `bin/ai-run`
- [x] 1.2 Add preflight dependency check for nano-brain runtime prerequisites
- [x] 1.3 Add known native-binding error signature matching
- [x] 1.4 Add auto-repair execution path for supported failures
- [x] 1.5 Add opt-out control (env/flag) for auto-repair behavior
- [x] 1.6 Suppress known non-fatal tree-sitter symbol-graph warnings on successful nano-brain runs (debug mode preserves diagnostics)

## 2. UX and Documentation

- [x] 2.1 Add clear log output for preflight checks and repair actions
- [x] 2.2 Update docs (`README.md` and/or `TROUBLESHOOTING.md`) with behavior and manual fallback commands

## 3. Verification

- [x] 3.1 Run shell lint/syntax checks for changed scripts
- [x] 3.2 Validate OpenSpec change with strict mode
- [x] 3.3 Verify nano-brain flow does not affect non-nano-brain tool execution
