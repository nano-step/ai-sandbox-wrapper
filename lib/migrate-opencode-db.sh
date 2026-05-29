#!/usr/bin/env bash
# migrate-opencode-db.sh — split global opencode SQLite DB into per-project DBs.
#
# Source DB:   ~/.local/share/opencode/opencode.db (read-only, never modified
#              except for a final rename after successful migration)
# Target DBs:  ~/.ai-sandbox/opencode-dbs/<human>-<8hex>/opencode.db
#
# Strategy:
#   1. Take a hot-safe snapshot of the source DB via `sqlite3 .backup`.
#   2. Backup the snapshot to ~/.ai-sandbox/opencode-dbs/.backups/<UTC-ts>/.
#   3. For each DISTINCT session.directory:
#      - compute new <human>-<8hex> identifier (same logic as bin/ai-run)
#      - create target DB with full schema cloned from source
#      - INSERT project + session + message + part + todo + session_message
#        + permission rows where session.directory matches
#      - verify counts
#   4. Print summary.
#   5. (Apply mode only) Rename live ~/.local/share/opencode/opencode.db
#      → opencode.db.migrated-<UTC-ts>  so opencode starts fresh.
#
# Default mode: DRY RUN — prints what would happen, makes no changes.
# Pass --apply to actually perform the migration.
#
# Usage:
#   bash lib/migrate-opencode-db.sh                # dry run
#   bash lib/migrate-opencode-db.sh --apply        # perform migration

set -e

SOURCE_DB="$HOME/.local/share/opencode/opencode.db"
TARGET_ROOT="$HOME/.ai-sandbox/opencode-dbs"
BACKUP_ROOT="$TARGET_ROOT/.backups"
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
SNAPSHOT="/tmp/opencode-migrate-${TIMESTAMP}.db"

APPLY=false
[[ "${1:-}" == "--apply" ]] && APPLY=true

# Mirror of compute_opencode_project_hash() in bin/ai-run. Must stay in sync.
compute_project_identifier() {
  local workdir="$1"
  local project_id=""
  local remote_url toplevel real_path

  remote_url=$(git -C "$workdir" config --get remote.origin.url 2>/dev/null || true)
  if [[ -n "$remote_url" ]]; then
    project_id="git:${remote_url}"
  else
    toplevel=$(git -C "$workdir" rev-parse --show-toplevel 2>/dev/null || true)
    if [[ -n "$toplevel" ]]; then
      real_path=$(realpath "$toplevel" 2>/dev/null || echo "$toplevel")
      project_id="gitroot:${real_path}"
    else
      real_path=$(realpath "$workdir" 2>/dev/null || echo "$workdir")
      project_id="path:${real_path}"
    fi
  fi

  local hash human
  hash=$(printf '%s' "$project_id" | openssl dgst -sha256 -r | cut -c1-8)
  case "$project_id" in
    git:*)     human=$(echo "${project_id#git:}" | sed 's|.*/||; s|\.git$||') ;;
    gitroot:*) human=$(basename "${project_id#gitroot:}") ;;
    path:*)    human=$(basename "${project_id#path:}") ;;
  esac
  human=$(echo "$human" | tr ' ' '-' | tr -cd '[:alnum:]_-' | tr '[:upper:]' '[:lower:]' | cut -c1-30)
  [[ -z "$human" ]] && human="workspace"
  echo "${human}-${hash}"
}

phase_preflight() {
  echo "🔍 Pre-flight checks…"

  [[ -f "$SOURCE_DB" ]] || { echo "❌ Source DB not found: $SOURCE_DB"; exit 1; }
  command -v sqlite3 >/dev/null || { echo "❌ sqlite3 not installed"; exit 1; }
  command -v openssl >/dev/null || { echo "❌ openssl not installed"; exit 1; }

  local source_size
  source_size=$(du -h "$SOURCE_DB" | cut -f1)
  echo "  source DB:   $SOURCE_DB ($source_size)"
  echo "  target root: $TARGET_ROOT"
  echo "  mode:        $([[ "$APPLY" == "true" ]] && echo "APPLY (changes will be made)" || echo "DRY RUN")"
  echo ""
}

phase_snapshot() {
  echo "📸 Taking hot-safe snapshot of source DB…"
  echo "  → $SNAPSHOT"
  sqlite3 "$SOURCE_DB" ".backup '$SNAPSHOT'"
  local snap_size
  snap_size=$(du -h "$SNAPSHOT" | cut -f1)
  echo "  ✅ snapshot ready ($snap_size)"
  echo ""
}

phase_plan() {
  echo "🗺️  Planning migration…"
  echo ""
  PLAN_FILE="/tmp/opencode-migrate-plan-${TIMESTAMP}.tsv"
  : > "$PLAN_FILE"

  local dirs_query="SELECT directory, COUNT(*) AS c FROM session GROUP BY directory ORDER BY c DESC;"

  printf "  %-8s  %-32s  %s\n" "SESSIONS" "NEW DB FOLDER" "SOURCE DIRECTORY"
  printf "  %-8s  %-32s  %s\n" "--------" "-------------" "----------------"

  while IFS='|' read -r dir count; do
    [[ -z "$dir" ]] && continue
    local new_id
    new_id=$(compute_project_identifier "$dir")
    printf "  %-8s  %-32s  %s\n" "$count" "$new_id" "$dir"
    printf '%s\t%s\t%s\n' "$dir" "$new_id" "$count" >> "$PLAN_FILE"
  done < <(sqlite3 "$SNAPSHOT" "$dirs_query")

  echo ""
  local total_dirs total_sessions
  total_dirs=$(wc -l < "$PLAN_FILE" | tr -d ' ')
  total_sessions=$(awk -F'\t' '{s+=$3} END {print s}' "$PLAN_FILE")
  echo "  → $total_dirs directories, $total_sessions sessions total"
  echo "  → plan saved: $PLAN_FILE"
  echo ""
}

phase_backup() {
  if [[ "$APPLY" != "true" ]]; then
    echo "⏭️  Skipping durable backup (dry run)"
    echo ""
    return 0
  fi

  local backup_dir="$BACKUP_ROOT/$TIMESTAMP"
  echo "💾 Saving snapshot to durable backup location…"
  mkdir -p "$backup_dir"
  cp "$SNAPSHOT" "$backup_dir/opencode.db"
  echo "  ✅ backup: $backup_dir/opencode.db"

  cat > "$backup_dir/MIGRATION_INFO.txt" <<EOF
opencode DB migration
=====================
Timestamp:  $TIMESTAMP
Source:     $SOURCE_DB
Plan file:  $PLAN_FILE
Mode:       APPLY

This directory contains a snapshot of the live opencode.db taken just
before the per-project split. Restore by copying opencode.db back to
$SOURCE_DB if you need to roll back.
EOF
  echo "  ✅ info:   $backup_dir/MIGRATION_INFO.txt"
  echo ""
}

split_one_directory() {
  local src_dir="$1"
  local new_id="$2"
  local expected="$3"
  local target_dir="$TARGET_ROOT/$new_id"
  local target_db="$target_dir/opencode.db"

  echo "  ▶ $new_id  ($expected sessions)  ← $src_dir"

  if [[ "$APPLY" != "true" ]]; then
    echo "    (dry run — would create $target_db)"
    return 0
  fi

  if [[ -f "$target_db" ]]; then
    echo "    ⚠️  target DB already exists — skipping (will not overwrite)"
    return 0
  fi

  mkdir -p "$target_dir"

  sqlite3 "$SNAPSHOT" ".schema" | sqlite3 "$target_db"

  # FK off + single transaction = bulk-insert speed. project_id rewrite
  # collapses all sessions of this directory under the new coherent project.
  sqlite3 "$target_db" <<SQL
PRAGMA foreign_keys = OFF;
ATTACH DATABASE '$SNAPSHOT' AS src;
BEGIN;

-- 1. Project row (synthetic, keyed by new_id)
INSERT OR REPLACE INTO project (id, worktree, vcs, name, icon_url, icon_color, time_created, time_updated, time_initialized, sandboxes, commands, icon_url_override)
SELECT
  '$new_id',
  '$src_dir',
  vcs,
  COALESCE(name, '$new_id'),
  icon_url,
  icon_color,
  time_created,
  time_updated,
  time_initialized,
  sandboxes,
  commands,
  icon_url_override
FROM src.project
WHERE id IN (SELECT DISTINCT project_id FROM src.session WHERE directory = '$src_dir')
ORDER BY time_created ASC
LIMIT 1;

-- If no project record existed (orphan project_ids), insert a minimal one.
INSERT OR IGNORE INTO project (id, worktree, time_created, time_updated, sandboxes)
VALUES (
  '$new_id',
  '$src_dir',
  (SELECT COALESCE(MIN(time_created), strftime('%s','now')*1000) FROM src.session WHERE directory = '$src_dir'),
  (SELECT COALESCE(MAX(time_updated), strftime('%s','now')*1000) FROM src.session WHERE directory = '$src_dir'),
  '[]'
);

-- 2. Sessions (rewrite project_id to new_id)
INSERT INTO session
SELECT
  id, '$new_id' AS project_id, parent_id, slug, directory, title, version,
  share_url, summary_additions, summary_deletions, summary_files, summary_diffs,
  revert, permission, time_created, time_updated, time_compacting, time_archived,
  workspace_id, path, agent, model, cost, tokens_input, tokens_output,
  tokens_reasoning, tokens_cache_read, tokens_cache_write
FROM src.session
WHERE directory = '$src_dir';

-- 3. Messages (filtered by session ids of this directory)
INSERT INTO message
SELECT m.* FROM src.message m
WHERE m.session_id IN (SELECT id FROM src.session WHERE directory = '$src_dir');

-- 4. Parts
INSERT INTO part
SELECT p.* FROM src.part p
WHERE p.session_id IN (SELECT id FROM src.session WHERE directory = '$src_dir');

-- 5. Todos
INSERT INTO todo
SELECT t.* FROM src.todo t
WHERE t.session_id IN (SELECT id FROM src.session WHERE directory = '$src_dir');

-- 6. Session messages
INSERT INTO session_message
SELECT sm.* FROM src.session_message sm
WHERE sm.session_id IN (SELECT id FROM src.session WHERE directory = '$src_dir');

-- 7. Session shares
INSERT INTO session_share
SELECT ss.* FROM src.session_share ss
WHERE ss.session_id IN (SELECT id FROM src.session WHERE directory = '$src_dir');

-- 8. Permission (one-per-project, rewrite project_id)
INSERT INTO permission
SELECT '$new_id', time_created, time_updated, data
FROM src.permission
WHERE project_id IN (SELECT DISTINCT project_id FROM src.session WHERE directory = '$src_dir')
LIMIT 1;

COMMIT;
DETACH DATABASE src;
PRAGMA foreign_keys = ON;
SQL

  local got
  got=$(sqlite3 "$target_db" "SELECT COUNT(*) FROM session;")
  if [[ "$got" -ne "$expected" ]]; then
    echo "    ❌ verification failed: expected $expected sessions, got $got"
    return 1
  fi
  local m p t
  m=$(sqlite3 "$target_db" "SELECT COUNT(*) FROM message;")
  p=$(sqlite3 "$target_db" "SELECT COUNT(*) FROM part;")
  t=$(sqlite3 "$target_db" "SELECT COUNT(*) FROM todo;")
  echo "    ✅ $got sessions, $m messages, $p parts, $t todos"
}

phase_split() {
  echo "✂️  Splitting per directory…"
  echo ""

  while IFS=$'\t' read -r dir new_id count; do
    split_one_directory "$dir" "$new_id" "$count"
  done < "$PLAN_FILE"

  echo ""
}

phase_finalize() {
  if [[ "$APPLY" != "true" ]]; then
    echo "✅ Dry run complete. Re-run with --apply to perform the migration."
    return 0
  fi

  echo "🏁 Finalizing…"
  local migrated_path="${SOURCE_DB}.migrated-${TIMESTAMP}"
  mv "$SOURCE_DB" "$migrated_path"
  # WAL/SHM moved too so next opencode launch starts from a clean empty DB.
  [[ -f "${SOURCE_DB}-wal" ]] && mv "${SOURCE_DB}-wal" "${migrated_path}-wal"
  [[ -f "${SOURCE_DB}-shm" ]] && mv "${SOURCE_DB}-shm" "${migrated_path}-shm"
  echo "  ✅ source DB moved to: $migrated_path"
  echo "  ✅ opencode will start with fresh global DB on next launch"
  echo "  ✅ per-project DBs available under: $TARGET_ROOT/"
  echo ""

  # Safe to delete /tmp snapshot — durable copy lives under $BACKUP_ROOT.
  rm -f "$SNAPSHOT"
}

main() {
  echo "╔════════════════════════════════════════════════════════════════╗"
  echo "║  OpenCode DB Migration  —  Global → Per-Project Split          ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo ""

  phase_preflight
  phase_snapshot
  phase_plan
  phase_backup
  phase_split
  phase_finalize

  echo "Done."
}

main "$@"
