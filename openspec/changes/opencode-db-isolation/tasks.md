## 1. Project identifier and storage helpers in bin/ai-run

- [x] 1.1 Add `compute_opencode_project_hash()` shell function that prints `<16-hex>` for the given workdir, using the hybrid resolver: `git config --get remote.origin.url` → `git rev-parse --show-toplevel` → `realpath $WORKDIR`. Pure function of `$1` (workdir). Use `openssl dgst -sha256 | head -c 16`.
- [x] 1.2 Add `opencode_db_dir()` that prints `$HOME/.ai-sandbox/opencode-dbs/<hash>/` for the given hash.
- [x] 1.3 Add `ensure_opencode_db_files()` that creates the per-project directory with `mkdir -p` (mode 0755) and `touch`es `opencode.db`, `opencode.db-wal`, `opencode.db-shm` inside it (mode 0644). All paths owned by `$USER`. Idempotent — does NOT clobber existing files.
- [x] 1.4 Add `ensure_opencode_backup()` that performs the one-time `cp` of `~/.local/share/opencode/opencode.db{,-wal,-shm}` (whichever exist) into `~/.ai-sandbox/opencode-dbs/.backups/<UTC-timestamp>/` and writes `.initialized`. No-ops if `.initialized` exists. Prints backup path to stderr.
- [x] 1.5 Add `append_opencode_db_mounts()` that emits the three `-v <host-file>:<container-file>:delegated` flags for the per-project SQLite trio. These are appended AFTER the existing `~/.local/share/opencode` directory mount in DOCKER_ARGS.

## 2. Container lifecycle helpers for opencode

- [x] 2.1 Add `opencode_container_name()` returning `ai-opencode-<hash>`.
- [x] 2.2 Add `opencode_container_running()` that checks `docker ps -q -f "name=^<name>$"`; prints container ID if running, empty otherwise.
- [x] 2.3 Add `opencode_container_stopped()` that returns non-empty when `docker ps -aq -f "name=^<name>$"` matches AND `opencode_container_running` is empty.
- [x] 2.4 Add `exec_into_opencode_container()` that:
  - validates `$CURRENT_DIR` is inside one of the running container's bind-mount sources (use `docker inspect --format '{{range .Mounts}}{{.Source}}\n{{end}}'`); if not, print warning to stderr and refuse the exec
  - prints `→ reusing ai-opencode-<hash> (existing opencode container for this project)` to stderr
  - executes `docker exec -it --workdir "$CURRENT_DIR" <name> opencode <args>`
  - on "no such container" race error, falls through to the run path
- [x] 2.5 Add `cleanup_stopped_opencode_container()` that runs `docker rm <name>` if `opencode_container_stopped` is non-empty.

## 3. Wire opencode branch into ai-run main flow

- [x] 3.1 Just before the `DOCKER_ARGS+=(...)` block (around `bin/ai-run:3069`), add an `if [[ "$TOOL" == "opencode" ]]; then ...; fi` branch.
- [x] 3.2 Inside the opencode branch: call `ensure_opencode_backup` (one-time), compute `project_hash`, set `OPENCODE_CONTAINER_NAME="ai-opencode-<hash>"`, and call `ensure_opencode_db_files`.
- [x] 3.3 In the opencode branch: if `opencode_container_running` returns non-empty, call `exec_into_opencode_container` with the user's args and `exit` with its status — do NOT proceed to `docker run`.
- [x] 3.4 In the opencode branch: if `opencode_container_stopped` returns non-empty, call `cleanup_stopped_opencode_container` then continue to fresh `docker run`.
- [x] 3.5 In the opencode branch: override `CONTAINER_NAME` with `--name $OPENCODE_CONTAINER_NAME` regardless of TTY (replacing the existing `if [[ -n "$TTY_FLAGS" ]]` gate at ~line 2136 for opencode only).
- [x] 3.6 In the opencode branch: rewrite the `DOCKER_ARGS+=($CONTAINER_NAME --rm $TTY_FLAGS)` line so `--rm` is OMITTED when tool is opencode. All other tools retain `--rm`.
- [x] 3.7 After the existing directory mounts are appended to DOCKER_ARGS (including `~/.local/share/opencode` via `TOOL_CONFIG_MOUNTS`), call `append_opencode_db_mounts` so the three file overlays come AFTER the directory mount (Docker mount-order precedence).
- [x] 3.8 Wrap the final `docker run` invocation so a "name already in use" failure triggers a single retry via `exec_into_opencode_container` (handles the simultaneous-first-launch race).

## 4. Guardrails / non-regression for other tools

- [ ] 4.1 Confirm via diff review that all opencode-specific logic is guarded by `[[ "$TOOL" == "opencode" ]]`.
- [ ] 4.2 Manual smoke test: run `ai-run claude --help` (or another non-opencode tool); verify via `docker ps -a` after exit that no container with `claude` name remains (i.e., `--rm` still works).
- [ ] 4.3 Manual smoke test: verify `~/.config/claude` and other claude paths are mounted exactly as before (no `opencode-dbs` mounts present).

## 5. Syntax & smoke tests for opencode

- [ ] 5.1 `bash -n bin/ai-run` passes.
- [ ] 5.2 `bash -n` passes on any other shell files touched.
- [ ] 5.3 Manual: in a git repo with origin remote, run `ai-run opencode`, verify (a) `~/.ai-sandbox/opencode-dbs/<hash>/opencode.db` exists on host with non-zero size after a TUI session creates one, (b) container `ai-opencode-<hash>` exists in `docker ps -a`.
- [ ] 5.4 Manual: in a subdirectory of the above git repo, run `ai-run opencode`, verify the SAME `<hash>` is used (same container name reused, same DB file).
- [ ] 5.5 Manual: in a non-git temp dir, run `ai-run opencode`, verify a DIFFERENT `<hash>` is used.
- [ ] 5.6 Manual: in `/tmp/scratch-a` and `/tmp/scratch-b` (both non-git), verify DIFFERENT hashes (proves path-based fallback isolates non-git dirs).
- [ ] 5.7 Manual: with opencode running in terminal A, run `ai-run opencode` in terminal B for the same project; verify B prints the reuse notice and attaches via `docker exec`. Verify both sessions write to the same DB file.
- [ ] 5.8 Manual: in the scenario above (A running, B attached), quit A first; verify B's opencode is killed (this confirms the documented known limitation).
- [ ] 5.9 Manual: verify that after first run with a pre-existing global DB, `~/.ai-sandbox/opencode-dbs/.backups/<timestamp>/opencode.db` exists and `.initialized` marker file exists.
- [ ] 5.10 Manual: re-run `ai-run opencode` and verify backup does NOT run a second time (no new timestamp dir).
- [ ] 5.11 Manual: verify file ownership — `ls -la ~/.ai-sandbox/opencode-dbs/<hash>/` shows files owned by `$USER` (not root), permissions 0644 / dir 0755.
- [ ] 5.12 Manual: `docker inspect ai-opencode-<hash>` — verify the three SQLite files appear as bind mounts AFTER the `~/.local/share/opencode` directory mount.

## 6. Non-interactive mode test

- [ ] 6.1 Manual: `echo "what is 2+2?" | ai-run opencode run` (or whatever the non-interactive invocation is) — verify the container is named `ai-opencode-<hash>` (deterministic, no random suffix).
- [ ] 6.2 Manual: verify a second piped invocation while the first is running attaches via `docker exec`.

## 7. Documentation

- [x] 7.1 Update `README.md` "Directory Structure" section: add a paragraph explaining per-project SQLite isolation under `~/.ai-sandbox/opencode-dbs/`, and that everything else stays shared.
- [x] 7.2 Add to README "What's New" a short entry: "OpenCode database is now isolated per-project to prevent SQLite corruption."
- [x] 7.3 Add a "Known Limitation: First terminal is master" subsection to `TROUBLESHOOTING.md` explaining: when two terminals open opencode for the same project, quitting the first terminal also kills the second; document workaround (use separate projects, or wait for first to finish).
- [x] 7.4 Add a "Rolling back DB isolation" subsection to `TROUBLESHOOTING.md` with the restore steps from `design.md` §Migration Plan.
- [x] 7.5 Add roadmap/TODO notes (in the repo's existing TODO/roadmap file or create a `ROADMAP.md`): (a) per-project session migration from backup, (b) container GC subcommands, (c) `--force-new` flag, (d) `OPENCODE_DB_ISOLATION=0` opt-out, (e) optional sentinel-process mode to decouple terminal A/B lifetimes.

## 8. Final verification

- [ ] 8.1 `openspec validate opencode-db-isolation --strict --no-interactive` passes.
- [ ] 8.2 Integrated test: open two terminals on the same project, launch opencode in both, confirm no SQLite corruption (`sqlite3 <db> "PRAGMA integrity_check;"` returns `ok`).
- [ ] 8.3 Integrated test: launch opencode in two unrelated non-git dirs simultaneously; confirm both work independently and produce separate `opencode.db` files with no cross-talk.
- [ ] 8.4 Verify via `docker inspect ai-opencode-<hash>` that the only NEW bind-mount sources (compared to pre-change behavior) are the three files under `~/.ai-sandbox/opencode-dbs/<hash>/`. All other mounts identical to today.
