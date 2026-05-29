## Context

`bin/ai-run` currently launches every tool — including opencode — as an ephemeral container with `--rm`, bind-mounting `~/.local/share/opencode` and `~/.config/opencode` from the host into the container's `/home/agent/...` paths (via the `mount_tool_config` helper at `bin/ai-run:1002-1014` and the registry at `bin/ai-run:963`). Container names are interactive-mode-only and carry a random suffix (`bin/ai-run:2094-2117`).

OpenCode persists session/message/part/todo data in a single SQLite database at `~/.local/share/opencode/opencode.db` with WAL journal mode (`opencode.db-wal`, `opencode.db-shm`). The WAL/SHM protocol relies on `mmap`+`fcntl` locks that are unreliable across Docker bind mounts, NFS, and multiple host processes. Two `ai-run opencode` invocations against the same host directory will produce two containers, each writing concurrently, and reliably corrupt the DB. Upstream patches (sst/opencode PR #14326 to switch journal modes, PR #21579 for per-session sharding) have been stalled for months.

This design intentionally takes the **smallest possible cut** at the problem: only the three SQLite files are isolated per-project; everything else (config, MCP servers, skills, JSON storage, logs, snapshots, auth) stays exactly as today. The reviewer's gap analysis ruled out broader isolation because (a) config isolation breaks MCP, and (b) full `share/` isolation introduces JSON-storage desync risks we don't need for the corruption fix.

Stakeholders: ai-sandbox-wrapper users who run opencode in more than one project or in multi-pane terminals.

## Goals / Non-Goals

**Goals:**
- Eliminate concurrent SQLite writes against the same opencode database by construction.
- Give every distinct project workdir on the host its own three SQLite files.
- Preserve every other piece of opencode behavior: config, MCP, skills, JSON storage, auth, logs, snapshots all stay shared across projects as today.
- Make container reuse automatic and transparent: a second `ai-run opencode` for the same project attaches to the existing container instead of spawning a corrupting twin.
- Back up existing global SQLite files once on upgrade, so no user silently loses session metadata.
- Keep the change opencode-specific; do not perturb other tools.
- Stay within Bash + `docker` + `git` + `openssl` — no new dependencies.

**Non-Goals:**
- Migrating historical session rows from the (backed-up) global DB into per-project DBs. Tracked separately.
- Isolating `~/.local/share/opencode/storage/`, `log/`, `snapshot/`, or any non-SQLite file. Accepted trade-off: those stay shared.
- Container garbage collection, idle timeout, or `ai-run --list-projects` / `--prune-projects` subcommands. Future work.
- `--force-new` / `OPENCODE_DB_ISOLATION=0` opt-out flags. Future work.
- Fixing SQLite WAL corruption inside opencode itself — upstream's problem.
- Windows-native support (WSL2 is supported and works the same as Linux).
- Cross-host isolation (e.g., NFS shared home). Outside the wrapper's mandate.
- A sentinel process to keep containers `Running` after the user quits the TUI. Containers go to `Exited` and the next invocation removes them.

## Decisions

### Decision 1: Hybrid project_id resolver (D1)

`project_id` is computed in this priority order, first match wins:

1. `git:<remote-origin-url>` — if `git -C "$WORKDIR" config --get remote.origin.url` succeeds.
2. `gitroot:<git-toplevel>` — else, if `git -C "$WORKDIR" rev-parse --show-toplevel` succeeds. Path is `realpath`'d.
3. `path:<realpath of $WORKDIR>` — fallback for non-git directories.

`project_hash = sha256("$project_id") | head -c 16` (16 hex chars / 64 bits).

**Rationale:**
- Matches OpenCode's own resolver semantics (git-remote first, git-root fallback) so opening `frontend/` and `backend/` subdirs of the same repo Just Works.
- The third rule (`path:` for non-git) is the deliberate departure from opencode's own logic: opencode lumps every non-git directory into `"global"`, which is a corruption trigger today. We give each non-git workdir its own SQLite trio.

**Alternatives considered:**
- *Pure path-based hashing.* Rejected: would split `frontend/` and `backend/` of the same repo into separate session pools.
- *Reuse opencode's exact algorithm including `"global"` fallback.* Rejected: would not fix the non-git case.

### Decision 2: File-level bind mount overlay (Q1 answer)

Per-project storage is **only** the three SQLite files, mounted file-by-file on top of the existing directory mount:

```
# Existing directory mount (kept, unchanged):
-v ~/.local/share/opencode:/home/agent/.local/share/opencode:delegated

# New file-level overlays (added AFTER the directory mount):
-v ~/.ai-sandbox/opencode-dbs/<hash>/opencode.db:/home/agent/.local/share/opencode/opencode.db:delegated
-v ~/.ai-sandbox/opencode-dbs/<hash>/opencode.db-wal:/home/agent/.local/share/opencode/opencode.db-wal:delegated
-v ~/.ai-sandbox/opencode-dbs/<hash>/opencode.db-shm:/home/agent/.local/share/opencode/opencode.db-shm:delegated
```

Mount order matters: Docker resolves overlapping bind mounts in declaration order, with the most-specific path winning. The directory mount provides everything else (storage/, log/, snapshot/, sessions/, auth.json) from the shared global path; the three file mounts replace just the SQLite trio.

**Why file-level mounts work:**
- The three files must exist on the host before mount, or Docker creates them as directories. The wrapper `touch`es all three before invoking `docker run`.
- The kernel guarantees that opencode reading/writing `/home/agent/.local/share/opencode/opencode.db` inside the container goes to the per-project file on the host, not the global one. SQLite's WAL/SHM files (`-wal`, `-shm`) are likewise per-project.
- OpenCode itself is unchanged and unaware: it still reads/writes the exact path it expects.

**Alternatives considered:**
- *Replace the entire `~/.local/share/opencode` mount with a per-project directory.* Rejected: would isolate storage/ and log/ too, which the reviewer flagged as causing JSON-storage desync risk and over-broadening scope.
- *Symlinks inside the container via entrypoint.* Rejected: requires touching the Dockerfile/entrypoint and is harder to debug.
- *`XDG_DATA_HOME` env var pointing per-project.* Rejected: it moves *all* opencode data, not just the SQLite files.

### Decision 3: Drop `--rm` for opencode containers; reuse by name (Q3 answer = Approach A)

Container name for opencode: `ai-opencode-<project_hash>` (deterministic, no random suffix, used in both interactive and non-interactive modes). For every other tool the existing random-suffix naming and `--rm` stay.

Lifecycle (opencode only):
1. Compute `project_hash` and the canonical name `ai-opencode-<hash>`.
2. `docker ps -q -f "name=^ai-opencode-<hash>$"` — if non-empty, container is **running**:
   - `exec` path: `docker exec -it --workdir "$CURRENT_DIR" ai-opencode-<hash> opencode <args>`. Print one-line stderr notice. Exit with exec's status.
3. Else `docker ps -aq -f "name=^ai-opencode-<hash>$"` — if non-empty, container is **stopped** (`Exited`):
   - `docker rm ai-opencode-<hash>` to clean up, then fall through to fresh run.
4. Else: `docker run --name ai-opencode-<hash> ... opencode <args>` **without `--rm`**. Container persists in `Exited` state after the TUI quits.
5. If `docker run` returns "name already in use" (race between two simultaneous first invocations), retry the exec path once.

**No sentinel process.** PID 1 is opencode itself. When opencode exits, the container goes to `Exited` (not removed). The next invocation cleans it up and runs fresh.

**Known limitation (Q3 known issue, accepted):** When two terminals are open against the same project:
- Terminal A's invocation = `docker run` → PID 1 = opencode TUI #1
- Terminal B's invocation = `docker exec` → child process inside the same container = opencode TUI #2
- If terminal A's user quits first, Docker kills the entire container (because PID 1 exited), which terminates B's opencode too.
- "First terminal is master." Document in README, TROUBLESHOOTING, and proposal Impact section.

**Why this is acceptable**: the alternative (sentinel `sleep infinity` keeping the container `Running` forever) means containers never get GC'd and accumulate; in MVP we explicitly prefer the simpler model and document the trade-off. A future change can add an opt-in sentinel mode.

**Alternatives considered:**
- *Lock file (flock) + keep `--rm`.* Rejected: equivalent correctness but loses container reuse for legitimate concurrent attaches.
- *Sentinel process to decouple TUI lifecycle from container.* Rejected for MVP; tracked in roadmap.

### Decision 4: One-time backup

On every opencode invocation, before any per-project setup:
- Check for the marker `~/.ai-sandbox/opencode-dbs/.backups/.initialized`. If present, skip backup entirely.
- Else: compute `BACKUP_DIR=~/.ai-sandbox/opencode-dbs/.backups/$(date -u +%Y%m%dT%H%M%SZ)/`.
- For each of `~/.local/share/opencode/opencode.db{,-wal,-shm}` that exists on host, **copy** (not move) it into `$BACKUP_DIR/`.
- Write `.initialized` containing timestamp + list of files backed up.
- Print `→ backed up pre-existing opencode SQLite files to $BACKUP_DIR` to stderr.

**Rationale:** Copy (not move) so the user's existing global SQLite keeps working if they invoke opencode natively on the host during transition. Disk usage of one SQLite snapshot is negligible. Single marker means backup runs at most once.

### Decision 5: Container name is deterministic in both interactive and non-interactive modes

For opencode only, the wrapper overrides the existing `if [[ -n "$TTY_FLAGS" ]]; then CONTAINER_NAME="--name $(generate_container_name)"; fi` logic and always sets `CONTAINER_NAME="--name ai-opencode-<hash>"`. The single-writer enforcement requires a deterministic name regardless of input mode.

Implication: a `echo "fix" | ai-run opencode` invocation participates in the same container-reuse machinery as an interactive `ai-run opencode`. If a running container exists, the piped invocation exec's into it.

### Decision 6: Opencode tool gate

All opencode-specific behavior in `bin/ai-run` (file-level overlays, deterministic name, no-`--rm`, container reuse, backup) MUST be guarded by `if [[ "$TOOL" == "opencode" ]]`. No other tool sees any change. This keeps the diff surgical and reviewable.

### Decision 7: Host-uid handling

The container's `agent` user is UID 1001. The wrapper creates `~/.ai-sandbox/opencode-dbs/<hash>/` and `touch`es the three SQLite files as the invoking host user. Bind mounts pass through host UID, so the in-container `agent` user must be able to read/write them.

This works today for `~/.ai-sandbox/home` (mounted into `/home/agent` at `bin/ai-run:3097`), which uses the same UID translation. We apply the identical convention: create as `$USER`, rely on existing host-uid mapping. No new code needed beyond `mkdir -p` + `touch`.

## Risks / Trade-offs

- **[R1] Stopped containers accumulate in `docker ps -a` only briefly.** Since each new invocation removes the prior stopped container with the same name before running, only one stopped container per project ever exists. → Acceptable, no GC needed.
- **[R2] Two simultaneous first invocations race past the "is it running?" check.** `docker run --name <X>` is atomic at the daemon level — second invocation fails with name conflict. → Mitigation: catch the error, fall through to exec.
- **[R3] User has native opencode running on host during backup.** We `cp` (not move) so host opencode keeps its files. Mid-WAL state in the backup is still recoverable. → Document in release notes.
- **[R4] git subprocess overhead.** ~10-30 ms per launch. Trivial vs `docker run` cost. → No optimization needed.
- **[R5] 16-hex-char hash collision.** ≈2⁻⁶⁴ per pair. → None needed; document.
- **[R6] Loss of cross-project session search.** Previously, opencode's TUI showed sessions from all projects in a global list; now sessions are scoped per-project. → Documented behavior change. Backup retains the unified DB for inspection via `sqlite3`.
- **[R7] Stale opencode binary in reused container.** If the user rebuilds the image between invocations, the reused container still has the old binary. → User can force fresh by `docker rm ai-opencode-<hash>`. Document.
- **[R8] First-terminal-exit kills second terminal's opencode.** Accepted limitation of Decision 3. → Document prominently as known issue.
- **[R9] JSON storage in `~/.local/share/opencode/storage/` remains shared across projects.** A part referenced by a session in DB-A may also be referenced (or not) by storage payloads visible to DB-B. Opencode's data model is robust to "extra" storage files (just inert), so the worst case is a few dead JSON payloads. Not a corruption risk. → Documented trade-off; not addressed in MVP.
- **[R10] File-level bind mounts require the source file to exist on host.** If the wrapper forgets to `touch` before `docker run`, Docker creates the path as a directory and opencode crashes opening "database". → Mitigation: explicit `touch` step before every `docker run`/exec; covered by smoke tests.
- **[R11] Mount-order dependency.** The three file mounts MUST follow the directory mount. If a future refactor reorders mounts, file overlays could be shadowed. → Mitigation: keep both the directory mount and the three file mounts in a single, clearly-commented opencode block in `bin/ai-run`.

## Migration Plan

**Deployment:**
1. Ship `bin/ai-run` changes on the `beta` branch first.
2. CI runs `bash -n` and existing tests; new smoke tests added by tasks.
3. Merge to `master` after one round of dogfooding.

**User-visible rollout:**
- On first `ai-run opencode` after upgrade, user sees:
  - `→ backed up pre-existing opencode SQLite files to ~/.ai-sandbox/opencode-dbs/.backups/<timestamp>/` (if global DB existed)
  - `→ initialized project storage: ~/.ai-sandbox/opencode-dbs/<hash>/`
  - Opencode TUI launches with an empty session list (we did NOT migrate session rows).
- Their old sessions remain in the backup `.db` file; can be inspected via `sqlite3` or restored manually if needed.

**Rollback strategy:**
1. User downgrades or pins the previous wrapper version.
2. Restore: `cp ~/.ai-sandbox/opencode-dbs/.backups/<timestamp>/opencode.db ~/.local/share/opencode/opencode.db` (and `-wal`/`-shm` if present).
3. Remove containers: `docker rm $(docker ps -aq -f "name=^ai-opencode-")`.
4. (Optional) Remove per-project SQLite files: `rm -rf ~/.ai-sandbox/opencode-dbs/` (but keep `.backups/` if they want to keep history).

Document rollback in `TROUBLESHOOTING.md`.

## Open Questions

- **Q1: docker exec --workdir validation.** When terminal B is in a directory NOT covered by the workspace whitelist OR not mounted into the running container, `docker exec --workdir <bad-path>` will exec but opencode will then fail to read the dir. **Resolution direction:** tasks 2.4 / 5.7 will print a clear warning when `$CURRENT_DIR` is not inside any of the workspaces mounted into the running container, and refuse exec in that case. Concrete check: parse `docker inspect`'s `Mounts[]` array for the running container, verify `$CURRENT_DIR` is under some mount source.

- **Q2: Notice format for container reuse.** Stderr, one line, fixed format: `→ reusing ai-opencode-<hash> (existing opencode container for this project)`. Finalized in implementation.

- **Q3: Should opencode containers participate in `--network`?** Yes. The first invocation pins network membership (`-n` flag); subsequent `docker exec` invocations inherit it automatically. If terminal B passes `-n` with a different network, the wrapper SHALL warn and ignore it (the container's network is fixed at run time). To be verified in implementation.

- **Q4: TTY differences between run and exec.** First invocation gets `-it` from the existing TTY flag logic. The exec path passes `-it` only when there's a TTY (interactive). Pipe input → no `-it`, exec still works. To be verified in smoke tests.
