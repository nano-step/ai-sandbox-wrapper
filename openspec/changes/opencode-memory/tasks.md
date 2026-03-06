## 1. Project Scaffolding

- [x] 1.1 Create new repository at ~/workspaces/self/AI/Tools/opencode-memory/ with package.json (name: @opencode-memory/server, type: module, bin entry)
- [x] 1.2 Configure TypeScript (tsconfig.json: strict, ESNext target, Bun types)
- [x] 1.3 Install core dependencies: better-sqlite3, sqlite-vec, node-llama-cpp, @modelcontextprotocol/sdk, chokidar, fast-glob, yaml, zod
- [x] 1.4 Install dev dependencies: vitest, @types/better-sqlite3, tsx
- [x] 1.5 Create src/ directory structure: index.ts, server.ts, store.ts, search.ts, chunker.ts, embeddings.ts, reranker.ts, expansion.ts, collections.ts, harvester.ts, watcher.ts, types.ts
- [x] 1.6 Create shell wrapper script (opencode-memory) that runs `bun src/index.ts`
- [x] 1.7 Set up vitest.config.ts and create test/ directory

## 2. Types & Schema

- [x] 2.1 Define shared types in types.ts: SearchResult, Document, MemoryChunk, Collection, HarvestedSession, BreakPoint, EmbeddingResult, RerankResult
- [x] 2.2 Implement SQLite schema initialization in store.ts: content, documents, documents_fts (FTS5), content_vectors, vectors_vec (sqlite-vec), llm_cache, collections tables
- [x] 2.3 Add WAL mode, foreign keys, and index creation
- [x] 2.4 Write tests for schema creation and basic CRUD operations

## 3. Markdown Chunking

- [x] 3.1 Implement break point scanner (scanBreakPoints) in chunker.ts: detect H1-H6, code fences, horizontal rules, blank lines, list items with scores
- [x] 3.2 Implement code fence region detection (track open/close ``` boundaries)
- [x] 3.3 Implement best cutoff finder (findBestCutoff): distance decay formula `baseScore × (1 - (distance/window)² × 0.7)`, code fence protection
- [x] 3.4 Implement main chunkMarkdown function: 900-token target (~3600 chars), 15% overlap (~540 chars), 200-token search window
- [x] 3.5 Implement SHA-256 content hashing for chunks and documents
- [x] 3.6 Write tests: basic chunking, code fence protection, overlap correctness, heading-aware splits, edge cases (empty doc, single line, huge code block)

## 4. SQLite Store & Data Layer

- [x] 4.1 Implement createStore() factory in store.ts: open/create SQLite database, load sqlite-vec extension, initialize schema
- [x] 4.2 Implement document operations: insertDocument, findDocument (by path or docid), getDocumentBody (with line range), deactivateDocument
- [x] 4.3 Implement content-addressable storage: insertContent (hash → body), deduplication on insert
- [x] 4.4 Implement FTS operations: auto-sync via triggers (INSERT/UPDATE/DELETE on documents → documents_fts)
- [x] 4.5 Implement vector operations: insertEmbedding (hash, seq, pos, embedding), ensureVecTable (create vec0 virtual table with correct dimensions)
- [x] 4.6 Implement embedding cache: check cache by content hash before embedding, store new embeddings
- [x] 4.7 Implement index health: getIndexHealth() returning doc count, chunk count, pending embeddings, collection stats
- [x] 4.8 Write tests for all store operations including hash deduplication and FTS sync

## 5. Local LLM Inference

- [x] 5.1 Implement model URI parsing and HuggingFace download in embeddings.ts: parse `hf:org/repo/file.gguf`, download with progress, cache to ~/.cache/opencode-memory/models/
- [x] 5.2 Implement EmbeddingGemma provider: load model via node-llama-cpp, create embedding context, embed() and embedBatch() methods
- [x] 5.3 Implement prompt formatting: "task: search result | query: {query}" for queries, "title: {title} | text: {content}" for documents
- [x] 5.4 Implement parallel embedding contexts: compute parallelism based on VRAM/CPU (GPU: 25% free VRAM / per-context, CPU: cores/4)
- [x] 5.5 Implement Qwen3-Reranker in reranker.ts: load model, create ranking context (2048 token context size), rankAll() for batch scoring
- [x] 5.6 Implement parallel reranking: split documents across contexts, reassemble scores
- [x] 5.7 Implement query expansion in expansion.ts: load Qwen3-1.7B, generate 2 query variants via LlamaChatSession
- [x] 5.8 Implement lazy model loading: only load embedding model on search, reranker + expander only on memory_query
- [x] 5.9 Implement graceful fallback: if any model fails to load, log warning and fall back to BM25-only mode
- [x] 5.10 Write tests for model loading, embedding generation, reranking, and fallback behavior (mock node-llama-cpp)

## 6. Search Pipeline

- [x] 6.1 Implement BM25 search (searchFTS) in search.ts: query FTS5 with BM25 ranking, normalize scores via Math.abs(), support collection filter and limit
- [x] 6.2 Implement vector search (searchVec): embed query, query sqlite-vec for cosine distance, convert to score via 1/(1+distance), support collection filter
- [x] 6.3 Implement RRF fusion: merge BM25 + vector results using `score = Σ(1/(k+rank+1))` where k=60, original query gets 2× weight
- [x] 6.4 Implement top-rank bonus: +0.05 for rank #1 in any list, +0.02 for rank #2-3
- [x] 6.5 Implement hybrid query pipeline: query expansion (2 variants) → parallel BM25+vector on all 3 queries → RRF fusion → top 30 candidates → LLM reranking → position-aware blending
- [x] 6.6 Implement position-aware blending: rank 1-3 = 75% RRF / 25% reranker, rank 4-10 = 60/40, rank 11+ = 40/60
- [x] 6.7 Implement LLM result caching: hash query+documents → cache reranking/expansion results in llm_cache table
- [x] 6.8 Implement minimum score threshold filtering and result limiting
- [x] 6.9 Implement result formatting: snippet (~700 chars), path, line range (start_line, end_line), score, docid (6-char hash)
- [x] 6.10 Write tests for each search mode, RRF fusion correctness, score normalization, and caching

## 7. Collection Management

- [x] 7.1 Implement YAML config in collections.ts: load/save ~/.config/opencode-memory/config.yml
- [x] 7.2 Implement collection operations: addCollection (name, path, glob pattern), removeCollection, listCollections, renameCollection
- [x] 7.3 Implement context annotations: addContext (collection + path prefix → description text), findContextForPath, listAllContexts
- [x] 7.4 Implement file scanning: use fast-glob to find Markdown files matching collection patterns
- [x] 7.5 Implement indexing pipeline: scan files → hash content → compare with stored hash → chunk changed files → store in SQLite → update FTS
- [x] 7.6 Write tests for YAML config round-trip, collection CRUD, context matching

## 8. Session Harvester

- [x] 8.1 Implement OpenCode storage parser in harvester.ts: read session JSON (ses_*.json), message JSON (msg_*.json), part JSON (prt_*.json)
- [x] 8.2 Implement synthetic part filtering: skip parts with `"synthetic": true` (system prompts)
- [x] 8.3 Implement Markdown generation: YAML frontmatter (session, agent, date, title, project) + ## User / ## Assistant (agent) sections
- [x] 8.4 Implement delta detection: track last-harvested timestamp per project, only process sessions modified after
- [x] 8.5 Implement output path generation: ~/.opencode-memory/sessions/{project-hash}/YYYY-MM-DD-{slug}.md
- [x] 8.6 Implement storage format version detection: gracefully handle unknown formats with warning
- [x] 8.7 Write tests with sample OpenCode JSON fixtures

## 9. Auto-Indexing Daemon

- [x] 9.1 Implement file watcher in watcher.ts: chokidar watching ~/.opencode-memory/ for .md file changes, 2-second debounce
- [x] 9.2 Implement dirty flag mechanism: set dirty=true on file change, actual reindex on next search or scheduled interval
- [x] 9.3 Implement interval polling: every 5 minutes, scan all collections for hash changes
- [x] 9.4 Implement session harvester polling: every 2 minutes, check OpenCode storage for new sessions
- [x] 9.5 Implement startup integrity check: verify stored hashes match file content, re-index mismatches
- [x] 9.6 Write tests for watcher debouncing, dirty flag behavior, delta sync

## 10. MCP Server

- [x] 10.1 Implement MCP server in server.ts using @modelcontextprotocol/sdk: register 8 tools with zod input schemas
- [x] 10.2 Implement memory_search tool: BM25 keyword search with collection filter, limit, minScore params
- [x] 10.3 Implement memory_vsearch tool: vector semantic search with same params
- [x] 10.4 Implement memory_query tool: full hybrid search with expansion + reranking
- [x] 10.5 Implement memory_get tool: retrieve document by path or docid (#abc123), support fromLine and maxLines
- [x] 10.6 Implement memory_multi_get tool: batch retrieve by glob pattern or comma-separated list, maxBytes filter
- [x] 10.7 Implement memory_write tool: append to daily log (memory/YYYY-MM-DD.md) or write to MEMORY.md
- [x] 10.8 Implement memory_status tool: return index health, collection info, model status, pending embeddings
- [x] 10.9 Implement memory_update tool: trigger immediate reindex of all collections
- [x] 10.10 Implement stdio transport (default): launch as subprocess via `opencode-memory mcp`
- [x] 10.11 Implement HTTP transport: `opencode-memory mcp --http --port 8282` with POST /mcp and GET /health endpoints
- [x] 10.12 Implement daemon mode: --daemon flag, PID file at ~/.cache/opencode-memory/mcp.pid, `opencode-memory mcp stop` command
- [x] 10.13 Write tests for each MCP tool (mock store), transport initialization, error handling

## 11. CLI Entry Point

- [x] 11.1 Implement CLI dispatcher in index.ts using manual arg parsing: subcommands for collection, status, update, embed, search, vsearch, query, get, mcp
- [x] 11.2 Implement `opencode-memory collection add/remove/list/rename` commands
- [x] 11.3 Implement `opencode-memory status` command: show index health, collections, model status
- [x] 11.4 Implement `opencode-memory update` command: re-scan all collections, index new/changed files
- [x] 11.5 Implement `opencode-memory embed` command: generate embeddings for all unembedded chunks (with --force flag for full re-embed)
- [x] 11.6 Implement `opencode-memory search/vsearch/query` commands: CLI search with --json, --files, --full, --min-score, -n, -c flags
- [x] 11.7 Implement `opencode-memory get` command: retrieve document by path or docid
- [x] 11.8 Implement `opencode-memory harvest` command: manually trigger session harvesting

## 12. OpenCode Integration

- [x] 12.1 Create OpenCode MCP config snippet (opencode.json fragment) for drop-in setup
- [x] 12.2 Create OpenCode skill definition (SKILL.md) that documents memory_search/memory_write tools for agents
- [x] 12.3 Write setup instructions: install, configure, first run, verify
- [ ] 12.4 Test end-to-end: install opencode-memory → configure in OpenCode → start session → agent uses memory_search → verify results

## 13. Testing & Polish

- [x] 13.1 Run full test suite, fix any failures (246/246 passing)
- [x] 13.2 Test on Linux (container environment)
- [ ] 13.3 Test with real OpenCode sessions: harvest → index → search → verify relevance
- [ ] 13.4 Test model download flow: first run, cache hit, corrupted cache recovery
- [ ] 13.5 Test daemon mode: start, health check, stop, restart
- [ ] 13.6 Add README.md with installation, configuration, usage, and architecture overview
