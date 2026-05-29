# Migration Guide

## v5.3.x → v5.4.x — OpenCode Per-Project Database Isolation

### TL;DR

Starting **v5.4.0**, OpenCode now uses a separate SQLite database per project
to prevent corruption from concurrent writes
([sst/opencode#14194](https://github.com/sst/opencode/issues/14194)).

**If you don't act**, opencode launches with an empty session list (your old
sessions are still safe on disk but not visible to opencode until you migrate
or opt out).

Choose **one** of three paths:

1. **[Recommended] Migrate** — keep all your old sessions, get the corruption fix
2. **[Quick] Skip migration** — accept fresh session history per project, get the fix
3. **[Opt-out] Disable isolation** — keep legacy behavior, no corruption fix

---

## Path 1 — Migrate (recommended)

The migration script splits your existing global database
(`~/.local/share/opencode/opencode.db`) into per-project databases under
`~/.ai-sandbox/opencode-dbs/<project-name>-<8hex>/`, preserving session
history, messages, parts, and todos.

```bash
# 1. Stop any running opencode containers
docker ps -aq -f "name=^ai-opencode-" | xargs -r docker rm -f

# 2. Dry run — preview the migration plan, no changes made
npx @nano-step/ai-sandbox-wrapper@latest migrate-opencode-db

# 3. Apply — actually perform the split
npx @nano-step/ai-sandbox-wrapper@latest migrate-opencode-db --apply
```

The migration is non-destructive:

- A snapshot of your live DB is taken via `sqlite3 .backup` (safe against
  concurrent writes from a running opencode).
- A durable backup is written to
  `~/.ai-sandbox/opencode-dbs/.backups/<UTC-timestamp>/opencode.db` along
  with a `MIGRATION_INFO.txt` describing what was backed up.
- The original DB is renamed to `opencode.db.migrated-<UTC-timestamp>`
  rather than deleted, so you can restore it manually if needed.

After migration, open opencode in each project directory:

```bash
cd /path/to/some/project
ai-run opencode    # session history from that project should be visible
```

---

## Path 2 — Skip migration

If you don't care about preserving old sessions:

```bash
# Just start opencode in your project — a fresh per-project DB is created.
cd /path/to/your/project
ai-run opencode
```

Your old sessions remain in `~/.local/share/opencode/opencode.db` and can
be inspected later with `sqlite3` if you change your mind.

---

## Path 3 — Opt out (disable isolation)

Set the `OPENCODE_DB_ISOLATION` environment variable to `0` to fall back to
legacy behavior (single global DB, ephemeral container, random container
name, `--rm` flag):

```bash
# Per-invocation
OPENCODE_DB_ISOLATION=0 ai-run opencode

# Persist for your shell session
export OPENCODE_DB_ISOLATION=0
ai-run opencode

# Persist in your shell profile
echo 'export OPENCODE_DB_ISOLATION=0' >> ~/.zshrc
```

When opt-out is active:

- The container mounts `~/.local/share/opencode` directly (your existing
  global DB is used as-is).
- Container name uses the legacy random-suffix pattern.
- `--rm` flag is restored.
- **No protection against concurrent-write corruption.** This is the
  pre-v5.4.0 behavior in full.

---

## What changed in v5.4.0

### Added

- Per-project SQLite database isolation under
  `~/.ai-sandbox/opencode-dbs/<human-name>-<8hex>/opencode.db`
- Deterministic per-project container name: `ai-opencode-<human-name>-<8hex>`
- Single-writer enforcement: a second `ai-run opencode` invocation for the
  same project attaches to the running container via `docker exec` instead
  of spawning a corrupting twin.
- One-time backup of pre-existing global SQLite files on first launch.
- `npx @nano-step/ai-sandbox-wrapper migrate-opencode-db` subcommand for
  splitting the global DB into per-project DBs.
- `OPENCODE_DB_ISOLATION=0` environment variable for opt-out.

### Changed

- OpenCode containers now persist (`Exited` state) between invocations
  rather than being removed (`--rm` dropped for opencode only — other
  tools unchanged).
- OpenCode container name is now deterministic (`ai-opencode-<hash>`)
  even in non-interactive mode.

### Known Limitation — "First Terminal Is Master"

When you have two terminals open against the same project, the second
terminal attaches to the running container via `docker exec`. If you quit
the first terminal, Docker kills the entire container (PID 1 exits) and
the second terminal's opencode is killed too.

**Workarounds**:

- Coordinate which terminal is "master" and quit it last.
- Use separate project directories.
- Use the opt-out flag (`OPENCODE_DB_ISOLATION=0`) — at the cost of
  losing the corruption protection.

See `TROUBLESHOOTING.md` for details.

---

## Rolling back

If you need to roll back after migrating:

```bash
# 1. Stop opencode containers
docker ps -aq -f "name=^ai-opencode-" | xargs -r docker rm -f

# 2. Restore from backup
BACKUP=$(ls -1dt ~/.ai-sandbox/opencode-dbs/.backups/[0-9]* 2>/dev/null | head -1)
cp "$BACKUP/opencode.db" ~/.local/share/opencode/opencode.db

# 3. Opt out of isolation going forward
export OPENCODE_DB_ISOLATION=0
```

Or pin the previous package version:

```bash
npx @nano-step/ai-sandbox-wrapper@5.3.2 setup
```

---

## Questions or issues?

Open an issue:
[github.com/nano-step/ai-sandbox-wrapper/issues](https://github.com/nano-step/ai-sandbox-wrapper/issues)
