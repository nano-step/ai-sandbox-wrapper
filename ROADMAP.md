# Roadmap

## OpenCode DB Isolation — Future Work

The current isolation (per-project SQLite files, single-writer container reuse) intentionally has a minimal MVP scope. Tracked follow-ups:

- [ ] **Per-project session migration:** Copy historical sessions from the one-time backup DB into per-project DBs based on `project.worktree` field. Currently users start each project with an empty session list.
- [ ] **Container GC subcommands:** `ai-run --list-projects` (list known project hashes and their disk usage), `ai-run --prune-projects` (remove DBs for project paths that no longer exist on host).
- [ ] **`--force-new` flag:** Bypass container reuse and start a fresh container per invocation (useful for testing).
- [ ] **`OPENCODE_DB_ISOLATION=0` opt-out:** Env var to fall back to legacy global-DB behavior.
- [ ] **Opt-in sentinel mode** (`OPENCODE_PERSIST=1`): Keep container running with `sleep infinity` PID 1 so quitting terminal A does not kill terminal B's opencode. Trade-off: containers never auto-exit, require explicit cleanup.
