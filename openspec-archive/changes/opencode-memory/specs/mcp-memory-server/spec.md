## ADDED Requirements

### Requirement: Eight Memory Tools

The system SHALL expose 8 MCP tools: `memory_search` (BM25), `memory_vsearch` (vector), `memory_query` (hybrid), `memory_get` (retrieve document), `memory_multi_get` (batch retrieve), `memory_write` (write to memory), `memory_status` (index health), and `memory_update` (trigger reindex).

#### Scenario: BM25 search tool

- **WHEN** a client calls `memory_search` with query "authentication"
- **THEN** the system SHALL execute BM25 full-text search and SHALL return ranked results

#### Scenario: Vector search tool

- **WHEN** a client calls `memory_vsearch` with query "user login"
- **THEN** the system SHALL execute vector semantic search and SHALL return results ranked by cosine similarity

#### Scenario: Hybrid search tool

- **WHEN** a client calls `memory_query` with query "implement auth flow"
- **THEN** the system SHALL execute full hybrid search with query expansion, RRF fusion, and LLM reranking

#### Scenario: Retrieve document by ID

- **WHEN** a client calls `memory_get` with docid=42
- **THEN** the system SHALL return the complete document content from the `documents` table

#### Scenario: Batch retrieve multiple documents

- **WHEN** a client calls `memory_multi_get` with docids=[42, 43, 44]
- **THEN** the system SHALL return all three documents in a single response

#### Scenario: Write to memory

- **WHEN** a client calls `memory_write` with content and target="MEMORY.md"
- **THEN** the system SHALL write the content to `~/.opencode-memory/MEMORY.md` and SHALL trigger reindexing

#### Scenario: Index health status

- **WHEN** a client calls `memory_status`
- **THEN** the system SHALL return document count, collection count, last index time, and database size

#### Scenario: Trigger manual reindex

- **WHEN** a client calls `memory_update`
- **THEN** the system SHALL scan all collections for changes and SHALL reindex modified files

### Requirement: Stdio Transport

The system SHALL support stdio transport as the default mode. The MCP server SHALL be launched as a subprocess and SHALL communicate via stdin/stdout using JSON-RPC.

#### Scenario: Launch via stdio

- **WHEN** OpenCode launches `opencode-memory mcp` as a subprocess
- **THEN** the system SHALL read JSON-RPC requests from stdin and SHALL write responses to stdout

#### Scenario: Subprocess lifecycle

- **WHEN** the parent process terminates
- **THEN** the MCP server SHALL detect stdin closure and SHALL exit gracefully

### Requirement: HTTP Transport with Daemon Mode

The system SHALL support HTTP transport with optional daemon mode. HTTP mode SHALL accept `--http`, `--port`, and `--daemon` flags.

#### Scenario: HTTP server mode

- **WHEN** launched with `opencode-memory mcp --http --port 8282`
- **THEN** the system SHALL start an HTTP server on port 8282 and SHALL accept JSON-RPC requests via POST

#### Scenario: Daemon mode with PID file

- **WHEN** launched with `opencode-memory mcp --http --daemon`
- **THEN** the system SHALL fork to background, SHALL write PID to `~/.cache/opencode-memory/mcp.pid`, and SHALL detach from terminal

#### Scenario: Default port 8282

- **WHEN** launched with `opencode-memory mcp --http` without `--port`
- **THEN** the system SHALL use port 8282 by default

### Requirement: Health Endpoint

The system SHALL expose a health endpoint at `GET /health` when running in HTTP mode. The endpoint SHALL return JSON with status and uptime.

#### Scenario: Health check response

- **WHEN** a client sends `GET /health`
- **THEN** the system SHALL return `{"status": "ok", "uptime": 12345}` with HTTP 200

#### Scenario: Health check without authentication

- **WHEN** a client sends `GET /health` without credentials
- **THEN** the system SHALL return status without requiring authentication

### Requirement: Tool Input Schema Validation

The system SHALL validate tool inputs using Zod schemas. Invalid inputs SHALL return MCP error responses with descriptive messages.

#### Scenario: Validate required parameters

- **WHEN** a client calls `memory_search` without the required `query` parameter
- **THEN** the system SHALL return an MCP error with message "Missing required parameter: query"

#### Scenario: Validate parameter types

- **WHEN** a client calls `memory_get` with docid="abc" (string instead of number)
- **THEN** the system SHALL return an MCP error with message "Invalid parameter type: docid must be a number"

### Requirement: Tool Output Format

The system SHALL return tool outputs as text content with snippets, scores, paths, and metadata. Output SHALL be formatted for readability in chat interfaces.

#### Scenario: Search result formatting

- **WHEN** `memory_query` returns 3 results
- **THEN** the output SHALL include formatted text with snippet, path, line range, and score for each result

#### Scenario: Status output formatting

- **WHEN** `memory_status` is called
- **THEN** the output SHALL include human-readable text like "Documents: 1,234 | Collections: 3 | Last indexed: 2 minutes ago"

### Requirement: Error Handling

The system SHALL handle errors gracefully and SHALL return MCP error responses with appropriate error codes and messages. Errors SHALL NOT crash the server.

#### Scenario: Database connection error

- **WHEN** the SQLite database is locked or corrupted
- **THEN** the system SHALL return an MCP error with message "Database error: unable to access index" and SHALL NOT crash

#### Scenario: Model loading error

- **WHEN** a GGUF model fails to load
- **THEN** the system SHALL return an MCP error with message "Model loading failed: falling back to BM25-only search"

### Requirement: PID File Management for Daemon Mode

The system SHALL manage a PID file at `~/.cache/opencode-memory/mcp.pid` when running in daemon mode. The PID file SHALL be removed on clean shutdown.

#### Scenario: Write PID on daemon start

- **WHEN** launched with `--daemon`
- **THEN** the system SHALL write the process ID to `~/.cache/opencode-memory/mcp.pid`

#### Scenario: Remove PID on clean shutdown

- **WHEN** the daemon receives SIGTERM or SIGINT
- **THEN** the system SHALL remove the PID file before exiting

#### Scenario: Detect stale PID file

- **WHEN** starting daemon mode and a PID file exists but the process is not running
- **THEN** the system SHALL remove the stale PID file and SHALL start normally
