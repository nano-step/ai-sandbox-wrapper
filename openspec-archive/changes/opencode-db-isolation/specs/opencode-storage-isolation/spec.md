## ADDED Requirements

### Requirement: Project Identifier Resolution
When the user invokes opencode via `ai-run opencode`, the wrapper SHALL compute a deterministic `project_id` for the current working directory using a hybrid resolver, and SHALL hash that `project_id` into a stable directory-safe identifier (`project_hash`) used for all per-project paths and the container name.

The resolver MUST apply, in order, the first rule whose precondition is satisfied:
1. If the workdir is inside a git repository AND `git config --get remote.origin.url` succeeds with non-empty output, `project_id` MUST be `git:<remote-origin-url>` (exact unmodified output).
2. Else, if `git rev-parse --show-toplevel` succeeds (the workdir is inside a git repo without an `origin` remote), `project_id` MUST be `gitroot:<realpath-of-toplevel>`.
3. Else, `project_id` MUST be `path:<realpath-of-workdir>`.

`project_hash` MUST be derived as the first 16 hex characters of `sha256(project_id)`. It MUST be deterministic across invocations from the same workdir on the same host.

#### Scenario: Git repo with origin remote
- **WHEN** user runs `ai-run opencode` inside `/Users/x/project` which is a git repo with `origin = git@github.com:foo/bar.git`
- **THEN** the wrapper SHALL compute `project_id = "git:git@github.com:foo/bar.git"`
- **AND** the wrapper SHALL compute the same `project_hash` for any subdirectory of `/Users/x/project`
- **AND** the wrapper SHALL compute the same `project_hash` on subsequent invocations from any directory inside that repo

#### Scenario: Git repo without origin remote
- **WHEN** user runs `ai-run opencode` inside a git repo whose only remote is `upstream` (no `origin`)
- **AND** the git toplevel is `/Users/x/local-only`
- **THEN** the wrapper SHALL compute `project_id = "gitroot:/Users/x/local-only"`

#### Scenario: Non-git directory
- **WHEN** user runs `ai-run opencode` inside `/tmp/scratch-a` which is not a git repo
- **THEN** the wrapper SHALL compute `project_id = "path:/tmp/scratch-a"`

#### Scenario: Two unrelated non-git directories
- **WHEN** user runs `ai-run opencode` in `/tmp/scratch-a` then in `/tmp/scratch-b`
- **THEN** the two invocations SHALL produce different `project_hash` values
- **AND** they SHALL therefore use isolated SQLite database files

### Requirement: Per-Project SQLite File Layout
The wrapper SHALL maintain an isolated directory per `project_hash` on the host that holds ONLY the three SQLite files (`opencode.db`, `opencode.db-wal`, `opencode.db-shm`) for that project.

The layout MUST be:
- `~/.ai-sandbox/opencode-dbs/<project_hash>/opencode.db`
- `~/.ai-sandbox/opencode-dbs/<project_hash>/opencode.db-wal`
- `~/.ai-sandbox/opencode-dbs/<project_hash>/opencode.db-shm`

The wrapper MUST ensure all three host files exist (`touch` if absent) with the invoking user's ownership before launching the container, because file-level bind mounts require the source file to exist on the host.

No other files SHALL be created in `~/.ai-sandbox/opencode-dbs/<project_hash>/` by the wrapper. All other opencode data (sessions JSON, log/, snapshot/, storage/, auth.json, config) continues to live in the global `~/.local/share/opencode/` and `~/.config/opencode/` directories as before this change.

#### Scenario: First-time launch creates SQLite file placeholders
- **WHEN** `ai-run opencode` is invoked for a workdir whose `project_hash` directory does not exist
- **THEN** the wrapper SHALL create `~/.ai-sandbox/opencode-dbs/<project_hash>/`
- **AND** SHALL ensure `opencode.db`, `opencode.db-wal`, and `opencode.db-shm` exist as files (empty if newly created) in that directory
- **AND** all three files SHALL be owned by the invoking user

#### Scenario: Subsequent launch reuses SQLite files
- **WHEN** `ai-run opencode` is invoked for a workdir whose `project_hash` directory already exists with the three SQLite files
- **THEN** the wrapper SHALL NOT modify or truncate any of the three files
- **AND** their contents SHALL remain intact

### Requirement: File-Level Bind Mount Overlay For OpenCode
When the tool being launched is `opencode`, the wrapper SHALL overlay the three per-project SQLite files on top of the existing directory mount of `~/.local/share/opencode` by adding three file-level bind mounts after the directory mount.

Specifically, for opencode invocations the wrapper MUST add these mounts (in addition to, NOT replacing, the existing `~/.config/opencode` and `~/.local/share/opencode` directory mounts):
- `~/.ai-sandbox/opencode-dbs/<project_hash>/opencode.db` → `/home/agent/.local/share/opencode/opencode.db` (`:delegated`)
- `~/.ai-sandbox/opencode-dbs/<project_hash>/opencode.db-wal` → `/home/agent/.local/share/opencode/opencode.db-wal` (`:delegated`)
- `~/.ai-sandbox/opencode-dbs/<project_hash>/opencode.db-shm` → `/home/agent/.local/share/opencode/opencode.db-shm` (`:delegated`)

The three file-level mounts MUST appear AFTER the directory mount of `~/.local/share/opencode` in the docker run argument list, so they take precedence (Docker resolves overlapping bind mounts in declaration order; the most-specific path wins).

For all other tools (`claude`, `gemini`, `aider`, etc.) the existing mount behavior MUST be unchanged.

#### Scenario: OpenCode container sees per-project DB but shared everything else
- **WHEN** the wrapper launches an opencode container for `project_hash = abc123`
- **THEN** inside the container, `/home/agent/.local/share/opencode/opencode.db` SHALL be backed by `~/.ai-sandbox/opencode-dbs/abc123/opencode.db` on the host
- **AND** the same overlay SHALL apply to `opencode.db-wal` and `opencode.db-shm`
- **AND** inside the container, `/home/agent/.local/share/opencode/storage/` and other contents SHALL still be backed by `~/.local/share/opencode/storage/` on the host (shared, unchanged)
- **AND** inside the container, `/home/agent/.config/opencode` SHALL still be backed by `~/.config/opencode` on the host (shared, unchanged)

#### Scenario: Non-opencode tool unaffected
- **WHEN** the wrapper launches `claude` for any workdir
- **THEN** the mount configuration SHALL be identical to behavior before this change
- **AND** no `opencode-dbs` directory SHALL be mounted into the container

### Requirement: Deterministic Container Name For OpenCode
For opencode containers, the container name MUST be `ai-opencode-<project_hash>`, regardless of whether the invocation is interactive (has TTY) or non-interactive (piped input, CI).

This overrides the existing random-suffix naming pattern (`generate_container_name`) for opencode only. For all other tools the existing behavior (random suffix; name only set when TTY is present) MUST be preserved.

#### Scenario: Interactive opencode launch
- **WHEN** user runs `ai-run opencode` in a terminal with TTY
- **THEN** the container SHALL be named `ai-opencode-<project_hash>` exactly
- **AND** the name SHALL NOT contain a random suffix or folder-basename component

#### Scenario: Non-interactive opencode launch
- **WHEN** user runs `echo "fix bug" | ai-run opencode` (no TTY)
- **THEN** the container SHALL also be named `ai-opencode-<project_hash>` exactly
- **AND** the same single-writer enforcement rules SHALL apply

### Requirement: Single-Writer Container Reuse
The wrapper SHALL ensure that at most one container is writing to a given `project_hash`'s SQLite files at any time, by reusing an already-running container instead of spawning a second one.

Before launching opencode the wrapper MUST inspect the state of any container named `ai-opencode-<project_hash>`:
- If running: the wrapper SHALL invoke `docker exec -it --workdir <CURRENT_DIR> ai-opencode-<project_hash> opencode <args>` and exit with that command's status. A one-line stderr notice indicating the container is being reused SHALL be printed before the exec.
- If a stopped container with that name exists (`docker ps -aq` matches but `docker ps -q` does not): the wrapper SHALL remove it via `docker rm` before continuing.
- If no such container exists: the wrapper SHALL `docker run` a new container with that name and WITHOUT the `--rm` flag, so it persists in `Exited` state after the user quits the opencode TUI.

If `docker run` fails with the "container name is already in use" error (race condition where another invocation created the container in between the check and the run), the wrapper SHALL retry the running-container exec path once.

#### Scenario: Second concurrent invocation reuses running container
- **WHEN** an opencode container `ai-opencode-abc123` is already running (PID 1 = opencode TUI from terminal A)
- **AND** user runs `ai-run opencode` from a second terminal in the same project
- **THEN** the wrapper SHALL execute `docker exec -it --workdir <CURRENT_DIR> ai-opencode-abc123 opencode <args>`
- **AND** the wrapper SHALL NOT call `docker run`
- **AND** the wrapper SHALL print a one-line stderr notice indicating container reuse before the exec

#### Scenario: First invocation runs persistent container
- **WHEN** no container named `ai-opencode-abc123` exists in `docker ps -a`
- **AND** user runs `ai-run opencode` for the corresponding project
- **THEN** the wrapper SHALL invoke `docker run --name ai-opencode-abc123 ...` WITHOUT `--rm`
- **AND** after the user quits the TUI, the container SHALL remain in `docker ps -a` in `Exited` state

#### Scenario: Stopped container is cleaned up before relaunch
- **WHEN** a container named `ai-opencode-abc123` exists in `docker ps -a` but is in `Exited` state (no longer running)
- **AND** user runs `ai-run opencode` for the corresponding project
- **THEN** the wrapper SHALL remove the stopped container via `docker rm ai-opencode-abc123`
- **AND** SHALL then `docker run` a fresh container with the same name

#### Scenario: Different projects get different containers
- **WHEN** opencode is running for project A (container `ai-opencode-aaa111`)
- **AND** user runs `ai-run opencode` for project B (hash `bbb222`)
- **THEN** the wrapper SHALL start a new container `ai-opencode-bbb222`
- **AND** both containers SHALL run concurrently without sharing SQLite files

#### Scenario: Name-conflict race resolved by retry
- **WHEN** two `ai-run opencode` invocations for the same project race, both see no container, both attempt `docker run`
- **AND** one of them fails with "container name is already in use"
- **THEN** the failing invocation SHALL retry by falling through to the running-container exec path
- **AND** the user SHALL NOT see the raw docker error

### Requirement: Persistent Container Lifecycle For OpenCode
The wrapper SHALL launch opencode containers WITHOUT the `--rm` flag. Other tool containers retain existing `--rm` behavior.

Opencode containers go to `Exited` state when the user quits the TUI (PID 1 exits). Each new invocation removes the prior stopped container (see "Single-Writer Container Reuse") before starting a fresh one, so disk usage of stopped containers does not accumulate.

The wrapper MUST NOT introduce a sentinel process (e.g. `sleep infinity`) to keep the container alive after the user quits. Container persistence between invocations is automatic via `Exited` + `docker rm` on the next launch.

When the user has two terminals open against the same project and the first (PID 1) exits, the second terminal's `docker exec` opencode process WILL be killed by Docker. This is a known and accepted limitation; document accordingly.

#### Scenario: Container persists as Exited after opencode quit
- **WHEN** an opencode container is launched and the user exits the opencode TUI
- **THEN** the container SHALL appear in `docker ps -a` with status `Exited`
- **AND** the container SHALL NOT be auto-removed

#### Scenario: No sentinel process
- **WHEN** the wrapper invokes `docker run` for opencode
- **THEN** the container's PID 1 SHALL be `opencode` itself (no wrapper script forcing `sleep infinity` or similar)
- **AND** the container SHALL exit cleanly when opencode exits

#### Scenario: Other tools still use --rm
- **WHEN** the wrapper launches `claude` or `gemini`
- **THEN** the container SHALL be launched with `--rm` exactly as before this change

#### Scenario: First-terminal-exit kills second-terminal exec
- **WHEN** terminal A has the opencode TUI running (PID 1 in container `ai-opencode-X`)
- **AND** terminal B is attached via `docker exec` to the same container
- **AND** the user quits terminal A
- **THEN** the container's PID 1 SHALL exit
- **AND** terminal B's opencode process SHALL be terminated by Docker as part of container shutdown
- **AND** the container SHALL transition to `Exited` state (not removed, per the persistence rules above)

### Requirement: One-Time Global SQLite Backup
The first time the wrapper launches an opencode container after this change is deployed, it SHALL back up any pre-existing global SQLite files on the host before any per-project initialization can occur.

The wrapper MUST:
- Check for the marker file `~/.ai-sandbox/opencode-dbs/.backups/.initialized`. If it exists, skip backup entirely.
- Else, compute `BACKUP_DIR=~/.ai-sandbox/opencode-dbs/.backups/<UTC-timestamp>/`.
- For each existing file among `~/.local/share/opencode/opencode.db`, `~/.local/share/opencode/opencode.db-wal`, `~/.local/share/opencode/opencode.db-shm`, copy (do NOT move) it into `$BACKUP_DIR/`, preserving the filename.
- Write `.initialized` containing the backup timestamp and a list of files backed up.
- Print `→ backed up pre-existing opencode SQLite files to $BACKUP_DIR` to stderr.

The wrapper SHALL NOT touch any other files in `~/.local/share/opencode/`. The user's session JSON payloads, logs, and snapshots remain in place (and stay shared across projects per design).

The backup MUST run at most once across all opencode invocations.

#### Scenario: First-ever launch with existing global DB
- **WHEN** the user runs `ai-run opencode` for the first time after upgrading
- **AND** `~/.local/share/opencode/opencode.db` exists
- **THEN** the wrapper SHALL copy `~/.local/share/opencode/opencode.db` to `~/.ai-sandbox/opencode-dbs/.backups/<timestamp>/opencode.db`
- **AND** SHALL also copy `opencode.db-wal` and `opencode.db-shm` if they exist
- **AND** SHALL create `~/.ai-sandbox/opencode-dbs/.backups/.initialized`
- **AND** SHALL print the backup directory path to stderr
- **AND** the original files in `~/.local/share/opencode/` SHALL remain in place

#### Scenario: Subsequent launches skip backup
- **WHEN** the wrapper launches opencode and `~/.ai-sandbox/opencode-dbs/.backups/.initialized` already exists
- **THEN** the wrapper SHALL NOT inspect or copy `~/.local/share/opencode/opencode.db*` again
- **AND** SHALL proceed directly to per-project initialization

#### Scenario: First-ever launch without existing global SQLite
- **WHEN** the user runs `ai-run opencode` for the first time after upgrading
- **AND** none of `~/.local/share/opencode/opencode.db{,-wal,-shm}` exist
- **THEN** the wrapper SHALL still create `~/.ai-sandbox/opencode-dbs/.backups/.initialized` so the no-op check is recorded
- **AND** SHALL NOT fail

### Requirement: Security Boundary Preservation
The change MUST NOT weaken any existing sandbox security guarantee.

Specifically:
- No new host directories outside `~/.ai-sandbox/` SHALL be exposed to opencode containers.
- The container SHALL continue to run as the non-root `agent` user with `CAP_DROP=ALL`.
- The per-project directory `~/.ai-sandbox/opencode-dbs/<project_hash>/` and the three SQLite files inside it SHALL be owned by the invoking user with permissions no broader than 0644 (files) / 0755 (directory). No `sudo` or root-owned paths SHALL be introduced.
- The single-writer enforcement SHALL be per-user (Docker container names are namespaced to the daemon, and ai-run already operates under one user's Docker context).

#### Scenario: No additional host paths leak
- **WHEN** an opencode container is inspected via `docker inspect`
- **THEN** every bind-mount source SHALL be either inside `~/.ai-sandbox/`, inside a whitelisted workspace, or one of the pre-existing shared mounts (caches, env, `~/.config/opencode`, `~/.local/share/opencode`, etc.) as before this change
- **AND** the only new mount sources SHALL be the three files under `~/.ai-sandbox/opencode-dbs/<project_hash>/`

#### Scenario: Per-project files owned by user
- **WHEN** the wrapper creates `~/.ai-sandbox/opencode-dbs/<hash>/opencode.db` and siblings
- **THEN** the file owners SHALL be the invoking user (`$USER`), not root
- **AND** the file permissions SHALL be 0644 or stricter
- **AND** the parent directory permissions SHALL be 0755 or stricter
