## ADDED Requirements

### Requirement: MEMORY.md Curated Long-Term Memory

The system SHALL maintain a curated long-term memory file at `~/.opencode-memory/MEMORY.md`. This file SHALL be indexed for search and SHALL be writable via the `memory_write` tool.

#### Scenario: Create MEMORY.md on first use

- **WHEN** the system initializes and MEMORY.md does not exist
- **THEN** the system SHALL create an empty MEMORY.md file at `~/.opencode-memory/MEMORY.md`

#### Scenario: Index MEMORY.md content

- **WHEN** MEMORY.md is modified
- **THEN** the system SHALL chunk, embed, and index the content into the SQLite database

#### Scenario: Write to MEMORY.md via tool

- **WHEN** an agent calls `memory_write` with target="MEMORY.md" and content="Project uses JWT for auth"
- **THEN** the system SHALL append or replace the content in MEMORY.md based on the write mode

### Requirement: Daily Append-Only Logs

The system SHALL maintain daily append-only log files at `~/.opencode-memory/memory/YYYY-MM-DD.md`. Each day SHALL have a separate log file.

#### Scenario: Create daily log file

- **WHEN** the date is 2026-02-16 and no log file exists for that date
- **THEN** the system SHALL create `~/.opencode-memory/memory/2026-02-16.md`

#### Scenario: Append to daily log

- **WHEN** an agent calls `memory_write` with target="daily" and content="Implemented auth middleware"
- **THEN** the system SHALL append the content to today's log file with a timestamp

#### Scenario: Index daily logs

- **WHEN** a daily log file is modified
- **THEN** the system SHALL reindex the file to make new entries searchable

### Requirement: memory_write Tool

The system SHALL provide a `memory_write` tool that writes to MEMORY.md or daily logs. The tool SHALL support append mode for daily logs and replace mode for MEMORY.md sections.

#### Scenario: Append to daily log

- **WHEN** `memory_write` is called with target="daily" and content="Fixed bug in auth flow"
- **THEN** the system SHALL append the content to today's log file

#### Scenario: Replace MEMORY.md section

- **WHEN** `memory_write` is called with target="MEMORY.md", section="Auth", and content="Uses JWT tokens"
- **THEN** the system SHALL replace the "Auth" section in MEMORY.md with the new content

#### Scenario: Trigger reindex after write

- **WHEN** `memory_write` completes successfully
- **THEN** the system SHALL trigger reindexing of the modified file

### Requirement: YAML-Based Collection Config

The system SHALL maintain collection configuration in a YAML file at `~/.config/opencode-memory/config.yml`. The config SHALL define collections with name, path, pattern, and context fields.

#### Scenario: Load collection config on startup

- **WHEN** the system starts
- **THEN** the system SHALL read `~/.config/opencode-memory/config.yml` and SHALL load all defined collections

#### Scenario: YAML config format

- **WHEN** the config file contains `collections: [{name: "docs", path: "/path/to/docs", pattern: "**/*.md"}]`
- **THEN** the system SHALL create a collection named "docs" that indexes all markdown files in "/path/to/docs"

#### Scenario: Create default config if missing

- **WHEN** `~/.config/opencode-memory/config.yml` does not exist
- **THEN** the system SHALL create a default config with "memory" and "sessions" collections

### Requirement: Context Annotations per Collection

The system SHALL support optional context annotations for each collection. Context annotations SHALL provide searchability hints and SHALL be included in search results.

#### Scenario: Define context annotation in config

- **WHEN** a collection is defined with `context: "Technical documentation for API endpoints"`
- **THEN** the system SHALL store the context annotation in the `collections` table

#### Scenario: Include context in search results

- **WHEN** search results include documents from a collection with context annotation
- **THEN** the system SHALL include the context annotation in the result metadata

### Requirement: Auto-Indexing Daemon with File Watching

The system SHALL run an auto-indexing daemon that watches memory directories using chokidar with 2-second debounce. File changes SHALL trigger reindexing.

#### Scenario: Watch memory directories

- **WHEN** the daemon starts
- **THEN** the system SHALL watch `~/.opencode-memory/` and all collection paths for file changes

#### Scenario: Debounce file changes

- **WHEN** a file is modified 5 times within 2 seconds
- **THEN** the system SHALL trigger only one reindex operation after the 2-second debounce period

#### Scenario: Reindex on file change

- **WHEN** a watched file is modified
- **THEN** the system SHALL recompute the file hash, compare against stored hash, and SHALL reindex if changed

### Requirement: Session Harvester Polling

The system SHALL poll the OpenCode session storage directory every 2 minutes to harvest new sessions. Harvested sessions SHALL be automatically indexed.

#### Scenario: 2-minute session polling

- **WHEN** the daemon is running
- **THEN** the system SHALL check for new OpenCode sessions every 2 minutes

#### Scenario: Auto-index harvested sessions

- **WHEN** a new session is harvested to `~/.opencode-memory/sessions/{project}/YYYY-MM-DD-{slug}.md`
- **THEN** the system SHALL automatically index the new file

### Requirement: Dirty Flag Mechanism

The system SHALL use a dirty flag to track when files have changed. Actual reindexing SHALL occur on the next search or at scheduled intervals, not immediately on every file change.

#### Scenario: Set dirty flag on file change

- **WHEN** a watched file is modified
- **THEN** the system SHALL set a dirty flag for that collection

#### Scenario: Reindex on next search

- **WHEN** a search is executed and the dirty flag is set
- **THEN** the system SHALL reindex changed files before executing the search

#### Scenario: Scheduled reindex interval

- **WHEN** the dirty flag is set and 5 minutes have passed
- **THEN** the system SHALL trigger reindexing even if no search is executed

### Requirement: 5-Minute Interval Polling

The system SHALL perform interval polling every 5 minutes to scan all collections for changes via hash comparison. This SHALL catch changes missed by file watchers.

#### Scenario: 5-minute polling interval

- **WHEN** the daemon is running
- **THEN** the system SHALL scan all collections for changes every 5 minutes

#### Scenario: Hash-based change detection

- **WHEN** interval polling runs
- **THEN** the system SHALL compute SHA-256 hash of each file and SHALL compare against stored hashes in the database

### Requirement: Startup Integrity Check

The system SHALL perform an integrity check on startup by verifying file hashes against stored hashes. Mismatches SHALL trigger reindexing.

#### Scenario: Verify hashes on startup

- **WHEN** the system starts
- **THEN** the system SHALL compute hashes for all indexed files and SHALL compare against stored hashes

#### Scenario: Reindex on hash mismatch

- **WHEN** a file hash does not match the stored hash
- **THEN** the system SHALL reindex that file

#### Scenario: Detect deleted files on startup

- **WHEN** a file exists in the database but not on disk
- **THEN** the system SHALL set `active=0` for that document

### Requirement: CLI Commands

The system SHALL provide CLI commands for collection management (add, remove, list), status reporting, manual update, and embedding operations.

#### Scenario: Add collection via CLI

- **WHEN** a user runs `opencode-memory collection add docs /path/to/docs "**/*.md"`
- **THEN** the system SHALL add the collection to config.yml and SHALL index all matching files

#### Scenario: Remove collection via CLI

- **WHEN** a user runs `opencode-memory collection remove docs`
- **THEN** the system SHALL remove the collection from config.yml and SHALL deactivate all documents in that collection

#### Scenario: List collections via CLI

- **WHEN** a user runs `opencode-memory collection list`
- **THEN** the system SHALL display all collections with name, path, pattern, and document count

#### Scenario: Status command

- **WHEN** a user runs `opencode-memory status`
- **THEN** the system SHALL display index statistics including document count, collection count, database size, and last index time

#### Scenario: Manual update command

- **WHEN** a user runs `opencode-memory update`
- **THEN** the system SHALL scan all collections for changes and SHALL reindex modified files

#### Scenario: Embed command for testing

- **WHEN** a user runs `opencode-memory embed "test query"`
- **THEN** the system SHALL generate and display the embedding vector for the query
