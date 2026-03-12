## 1. Runtime Detection and Repair

- [ ] 1.1 Add nano-brain command detection in `bin/ai-run`
- [ ] 1.2 Add preflight dependency check for nano-brain runtime prerequisites
- [ ] 1.3 Add known native-binding error signature matching
- [ ] 1.4 Add auto-repair execution path for supported failures
- [ ] 1.5 Add opt-out control (env/flag) for auto-repair behavior

## 2. UX and Documentation

- [ ] 2.1 Add clear log output for preflight checks and repair actions
- [ ] 2.2 Update docs (`README.md` and/or `TROUBLESHOOTING.md`) with behavior and manual fallback commands

## 3. Verification

- [ ] 3.1 Run shell lint/syntax checks for changed scripts
- [ ] 3.2 Validate OpenSpec change with strict mode
- [ ] 3.3 Verify nano-brain flow does not affect non-nano-brain tool execution