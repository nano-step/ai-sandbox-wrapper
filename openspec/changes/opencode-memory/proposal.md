## Why

OpenCode agents have no memory across sessions. Every conversation starts from zero — past decisions, project context, user preferences, and debugging history are lost when a session ends. Sessions are stored as JSON blobs in `~/.local/share/opencode/storage/` but are never searchable or retrievable by agents. This makes long-running projects painful: agents re-discover the same patterns, forget architectural decisions, and can't recall what was tried before. QMD (github.com/tobi/qmd, 8.7k stars) has proven that hybrid BM25 + vector + LLM reranking over local Markdown files is the right approach — we want to build a purpose-built version for OpenCode as a **new standalone project** (not part of ai-sandbox-wrapper).

## What Changes

- **New project**: `opencode-memory` — a standalone TypeScript/Bun MCP server that provides persistent, searchable memory for OpenCode agents
- **Hybrid search pipeline**: Replicates QMD's 3-tier architecture — BM25 (SQLite FTS5) + vector semantic search (sqlite-vec + EmbeddingGemma-300M) + LLM reranking (Qwen3-Reranker-0.6B) with RRF fusion and position-aware blending
- **Smart markdown chunking**: Scored break points with code fence protection, ~900-token chunks with 15% overlap
- **Session harvester**: Watches OpenCode's JSON session storage and auto-converts conversations into searchable Markdown
- **Memory layers**: Curated long-term memory (`MEMORY.md`) + append-only daily logs (`memory/YYYY-MM-DD.md`) + harvested session transcripts
- **Multi-agent scoping**: Memories tagged by agent (sisyphus, explore, oracle), searchable cross-agent or scoped
- **Auto-indexing daemon**: File watcher + interval polling + delta-based sync via content hashing
- **MCP server**: Exposes `memory_search`, `memory_vsearch`, `memory_query`, `memory_get`, `memory_multi_get`, `memory_write`, `memory_status`, `memory_update` tools via stdio + HTTP transport
- **Local-first**: All GGUF models run via node-llama-cpp, no cloud APIs required
- **Drop-in OpenCode integration**: Ships with `opencode.json` config snippet for immediate setup
- **No changes to ai-sandbox-wrapper**: This is a sibling project, not a modification

## Capabilities

### New Capabilities
- `hybrid-search-pipeline`: BM25 full-text + vector semantic + LLM reranking search with RRF fusion, query expansion, and position-aware score blending
- `markdown-indexing`: Smart markdown chunking, content-addressable SQLite storage, FTS5 index, sqlite-vec vectors, embedding cache, and delta-based incremental sync
- `local-llm-inference`: Local GGUF model management for embeddings (EmbeddingGemma-300M), reranking (Qwen3-Reranker-0.6B), and query expansion (Qwen3-1.7B) via node-llama-cpp
- `mcp-memory-server`: MCP server exposing 8 memory tools (search, vsearch, query, get, multi_get, write, status, update) over stdio and HTTP transport
- `session-harvester`: Watches OpenCode's JSON session storage, extracts conversation text from message parts, and converts to searchable Markdown with agent tagging
- `memory-management`: MEMORY.md curated long-term memory, daily append-only logs, collection management via YAML config, context annotations, and auto-indexing daemon with file watching

### Modified Capabilities
<!-- None — this is a new standalone project with no changes to existing ai-sandbox-wrapper specs -->

## Impact

- **New repository**: `opencode-memory/` as a sibling project (or subdirectory — TBD based on preference)
- **Dependencies**: better-sqlite3, sqlite-vec, node-llama-cpp, @modelcontextprotocol/sdk, chokidar, fast-glob, yaml, zod, vitest
- **Disk usage**: ~2GB for GGUF models (auto-downloaded on first use to `~/.cache/opencode-memory/models/`)
- **Runtime**: Bun 1.0+ or Node.js 22+
- **OpenCode config**: Requires adding MCP server entry to `~/.config/opencode/opencode.json`
- **Storage**: SQLite database at `~/.cache/opencode-memory/index.sqlite`, memory files at `~/.opencode-memory/` (configurable)
- **No breaking changes**: Zero impact on existing ai-sandbox-wrapper functionality
