## Why

OpenCode's SQLite database at `~/.local/share/opencode/opencode.db` is shared across every invocation. Because `ai-run` spawns a fresh container per call (with `--rm`) and bind-mounts that single host directory, two concurrent invocations — or a host opencode plus a containerized one — write to the same SQLite WAL files and reliably corrupt the database. This matches the known unfixed upstream issue (sst/opencode#14194, #14970, #21443) and is currently hitting our users on every multi-pane / multi-project workflow.

Rather than wait for the stalled upstream fix (PR #14326), we eliminate concurrent writers at the wrapper layer by giving each "project" its own SQLite database files and ensuring only one container ever writes to a given project's database.

## What Changes

Scope is intentionally minimal: only the three SQLite files (`opencode.db`, `opencode.db-wal`, `opencode.db-shm`) are isolated per-project. Everything else in `~/.local/share/opencode` (sessions/, storage/, log/, snapshot/, auth.json, etc.) and all of `~/.config/opencode` (MCP servers, skills, settings) stays shared across projects, exactly as today.

- Compute a deterministic `project_id` per opencode invocation, using a hybrid resolver that mirrors how OpenCode itself identifies projects:
  1. `git:<remote-origin-url>` if the workdir is inside a git repo with a remote
  2. `gitroot:<absolute-path-to-git-toplevel>` if it's a git repo without a remote
  3. `path:<realpath-of-workdir>` for non-git directories
- Hash the `project_id` (sha256, truncated to 16 hex chars) into a stable directory identifier.
- Store the three SQLite files per project at `~/.ai-sandbox/opencode-dbs/<hash>/{opencode.db,opencode.db-wal,opencode.db-shm}` on the host.
- For opencode containers, **add three file-level bind mounts** that overlay the per-project SQLite files on top of the existing `~/.local/share/opencode` directory mount. All other mounts (including `~/.config/opencode`) stay exactly as today.
- Enforce single-writer-per-project: container name is `ai-opencode-<hash>`; if such a container is already running, `docker exec` into it instead of spawning a new one. Container name becomes deterministic for opencode (interactive and non-interactive both), not random-suffixed.
- **BREAKING** Drop the `--rm` flag for opencode containers; they go to `Exited` state after the user quits the TUI, and are removed automatically on the next invocation before a fresh container is started. (Non-opencode tools keep current `--rm` behavior.)
- On first run after upgrade, automatically back up the existing global SQLite files once (with timestamp) before initializing the new per-project layout.
- Migration of existing session metadata from the global DB into per-project DBs is **explicitly out of scope**.

## Capabilities

### New Capabilities
- `opencode-storage-isolation`: per-project SQLite file overlays, deterministic container naming with single-writer reuse for opencode, and one-time backup of pre-existing global SQLite files.

### Modified Capabilities
- (none — `container-runtime` and `tool-config-inspection` are not touched at the requirement level; only opencode-specific mount/lifecycle logic is added.)

## Impact

- **Affected code**:
  - `bin/ai-run` — opencode-specific branch for project_id resolution, three SQLite file bind mounts, deterministic container name, and exec-vs-run lifecycle
  - `lib/install-opencode.sh` — unchanged (binary install is independent)
  - `dockerfiles/opencode/Dockerfile` — unchanged
- **Host filesystem layout**:
  - New: `~/.ai-sandbox/opencode-dbs/<hash>/opencode.db` (and `-wal`, `-shm`)
  - New: `~/.ai-sandbox/opencode-dbs/.backups/<UTC-timestamp>/` (one-time backup)
  - Unchanged: `~/.config/opencode/` and `~/.local/share/opencode/` are still bind-mounted to the container as before; only the three SQLite files inside the latter are overlaid.
- **User-visible behavior**:
  - OpenCode containers now persist in `Exited` state in `docker ps -a` between invocations under the name `ai-opencode-<hash>`. Each new invocation removes the stopped container and runs a fresh one.
  - **Known limitation**: if two terminals open opencode for the same project, the second attaches to the running container via `docker exec`. When the first terminal (the container's PID 1) exits, the second terminal's opencode is killed too. Document as expected behavior; first-terminal-is-master.
  - Session metadata (rows in the per-project DB) is no longer shared across unrelated projects.
  - JSON storage payloads in `~/.local/share/opencode/storage/`, opencode logs, and snapshots remain shared (acceptable trade-off — they're not the contention point).
- **Out of scope** (tracked as TODO / roadmap):
  - Migration of historical sessions from global DB into per-project DBs
  - Isolating `~/.local/share/opencode/storage/`, `log/`, `snapshot/` (current trade-off accepts cross-project sharing of those)
  - Container GC / pruning (`ai-run --list-projects`, `--prune-projects`, idle timeout)
  - `--force-new` flag to bypass exec-into-existing
  - `OPENCODE_DB_ISOLATION=0` opt-out
- **Dependencies**: requires `git`, `openssl` (for sha256), `docker` on host — all already required.
- **Cross-platform**: relies on `realpath`, `git rev-parse`, `openssl dgst -sha256` — available on macOS, Linux, WSL2. No Windows-native support changes.
- **Security**: no new attack surface — bind mount paths are still inside `~/.ai-sandbox/`, no new host directories exposed; container reuse is per-user (Docker daemon socket access unchanged).
