## Context

OpenCode stores session data as JSON files across `~/.local/share/opencode/storage/{session,message,part,todo}/` but provides no mechanism for agents to search past sessions or recall cross-session context. QMD (github.com/tobi/qmd) has established the state-of-the-art for local hybrid search over Markdown files — BM25 + vector + LLM reranking with RRF fusion. We are building `opencode-memory`, a standalone MCP server that replicates QMD's search pipeline and adds OpenCode-specific features (session harvesting, multi-agent scoping, memory layers).

**Current state**: OpenCode agents start every session from zero. The only persistent context is `AGENTS.md` (static, manually maintained).

**Target state**: Agents can semantically search past sessions, curated memories, and daily logs via `memory_search`/`memory_query` MCP tools. Memory is automatically indexed and kept fresh.

## Goals / Non-Goals

**Goals:**
- Replicate QMD's full hybrid search pipeline (BM25 + vector + reranking + RRF fusion) for equivalent search quality
- Provide seamless OpenCode integration via MCP (stdio + HTTP transport)
- Auto-harvest OpenCode sessions from JSON storage into searchable Markdown
- Support curated long-term memory (`MEMORY.md`) and daily logs (`memory/YYYY-MM-DD.md`)
- Run 100% locally — no cloud APIs, no network dependencies after model download
- Delta-based incremental indexing — fast startup, minimal re-embedding cost
- Single `npm install -g` or `bun install -g` for setup

**Non-Goals:**
- Modifying OpenCode's core codebase (this is a standalone project)
- Supporting non-Markdown file formats (PDF, DOCX, etc.)
- Multi-user or networked memory sharing
- Cloud embedding providers (OpenAI, Gemini) — local-only for v1
- Real-time streaming search results
- GUI or web interface — CLI + MCP only

## Decisions

### D1: Standalone project vs OpenCode plugin

**Decision**: Standalone npm package (`@opencode-memory/server`) that runs as an MCP server.

**Why not an OpenCode skill?** OpenCode skills are Markdown instruction files — they can call tools but can't run daemons, manage SQLite, or embed chunks. A skill can only *reference* MCP tools, not *be* one.

**Why not fork QMD?** QMD is general-purpose and tightly coupled (90KB CLI entry point, 107KB store). We need OpenCode-specific features (session harvesting, agent scoping) that don't belong in QMD. Building from scratch with QMD as reference gives us a cleaner architecture.

**Why not use QMD as a dependency?** QMD is a CLI tool, not a library. Its internals aren't exported. We'd be shelling out to `qmd` commands, which is fragile and limits integration depth.

**Alternatives considered:**
- Fork QMD and add OpenCode features → rejected (maintenance burden, divergent goals)
- Use QMD as-is + write a thin wrapper → rejected (can't deeply integrate session harvesting)
- Contribute OpenCode features upstream to QMD → rejected (too domain-specific for a general tool)

### D2: Search architecture — 3-tier hybrid (same as QMD)

**Decision**: Replicate QMD's exact search pipeline:

```
Query → LLM Expansion (2 variants) → Parallel [BM25 + Vector] × 3 queries
      → RRF Fusion (k=60, original query 2× weight, top-rank bonus)
      → Top 30 candidates → LLM Reranking (Qwen3-Reranker)
      → Position-Aware Blending → Final Results
```

**Three search modes** (matching QMD):
1. `memory_search` — BM25 only (fast, ~30ms)
2. `memory_vsearch` — Vector only (semantic, ~2-3s)
3. `memory_query` — Full hybrid with expansion + reranking (best quality, ~10s)

**Why replicate exactly?** QMD's pipeline is well-tested (8.7k stars) and the position-aware blending solves a real problem — pure RRF can dilute exact matches when expanded queries don't match. No reason to deviate.

### D3: SQLite schema — content-addressable with FTS5 + sqlite-vec

**Decision**: Single SQLite database per workspace at `~/.cache/opencode-memory/{workspace-hash}.sqlite`.

**Schema** (adapted from QMD):

```sql
-- Content-addressable storage
CREATE TABLE content (
  hash TEXT PRIMARY KEY,          -- SHA-256 of document body
  body TEXT NOT NULL,
  created_at TEXT NOT NULL
);

-- Document metadata
CREATE TABLE documents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  collection TEXT NOT NULL,       -- 'memory', 'sessions', 'custom'
  path TEXT NOT NULL,             -- relative path within collection
  title TEXT NOT NULL,
  hash TEXT NOT NULL,
  agent TEXT,                     -- OpenCode agent name (nullable)
  created_at TEXT NOT NULL,
  modified_at TEXT NOT NULL,
  active INTEGER NOT NULL DEFAULT 1,
  FOREIGN KEY (hash) REFERENCES content(hash),
  UNIQUE(collection, path)
);

-- FTS5 full-text index
CREATE VIRTUAL TABLE documents_fts USING fts5(
  filepath, title, body,
  tokenize='porter unicode61'
);

-- Embedding chunks
CREATE TABLE content_vectors (
  hash TEXT NOT NULL,
  seq INTEGER NOT NULL DEFAULT 0,
  pos INTEGER NOT NULL DEFAULT 0,
  model TEXT NOT NULL,
  embedded_at TEXT NOT NULL,
  PRIMARY KEY (hash, seq)
);

-- sqlite-vec virtual table
CREATE VIRTUAL TABLE vectors_vec USING vec0(
  hash_seq TEXT PRIMARY KEY,
  embedding float[384] distance_metric=cosine
);

-- LLM result cache (query expansion, reranking)
CREATE TABLE llm_cache (
  hash TEXT PRIMARY KEY,
  result TEXT NOT NULL,
  created_at TEXT NOT NULL
);

-- Collection config
CREATE TABLE collections (
  name TEXT PRIMARY KEY,
  path TEXT NOT NULL,
  pattern TEXT NOT NULL DEFAULT '**/*.md',
  context TEXT
);
```

**Why per-workspace?** Different projects have different memory. A web app project shouldn't pollute a CLI tool's memory index.

**Why not per-agent?** Agents in OpenCode collaborate on the same project. Cross-agent search is more valuable than isolation. Agent tagging (the `agent` column) allows scoped queries when needed.

### D4: Chunking — smart break points (same as QMD)

**Decision**: 900-token chunks with 15% overlap, scored break points, code fence protection.

**Break point scoring** (from QMD):
| Pattern | Score |
|---------|-------|
| `# H1` | 100 |
| `## H2` | 90 |
| `### H3` | 80 |
| Code fence (```) | 80 |
| Horizontal rule | 60 |
| Blank line | 20 |
| List item | 5 |
| Line break | 1 |

**Cut algorithm**: When approaching 900-token target, search a 200-token window before cutoff. Score each break point: `finalScore = baseScore × (1 - (distance/window)² × 0.7)`. Cut at highest-scoring break point. Never split inside code fences.

**Why 900 tokens?** QMD's default, proven to work well. Large enough for semantic coherence, small enough for precise retrieval.

### D5: GGUF models — same as QMD

**Decision**: Use the same three models:

| Model | Purpose | Size | HuggingFace URI |
|-------|---------|------|-----------------|
| EmbeddingGemma-300M-Q8_0 | Vector embeddings | ~300MB | `hf:ggml-org/embeddinggemma-300M-GGUF/...` |
| Qwen3-Reranker-0.6B-Q8_0 | Cross-encoder reranking | ~640MB | `hf:ggml-org/Qwen3-Reranker-0.6B-Q8_0-GGUF/...` |
| qmd-query-expansion-1.7B-q4_k_m | Query expansion | ~1.1GB | `hf:tobil/qmd-query-expansion-1.7B-gguf/...` |

**Auto-download** on first use to `~/.cache/opencode-memory/models/`. Total ~2GB.

**Why these specific models?** They're what QMD uses and are proven to work well together. The query expansion model is fine-tuned specifically for this use case by QMD's author.

### D6: Session harvester — JSON → Markdown converter

**Decision**: A background process that watches `~/.local/share/opencode/storage/` and converts completed sessions into Markdown files.

**Harvesting flow**:
```
1. Watch ~/.local/share/opencode/storage/session/{project-hash}/ for new session files
2. When session detected (new or modified):
   a. Read session metadata (ses_*.json) → extract title, slug, timestamps
   b. Read message files (message/{sessionID}/msg_*.json) → extract role, agent
   c. Read part files (part/msg_*/prt_*.json) → extract conversation text
   d. Filter out synthetic parts (system prompts)
   e. Write to ~/.opencode-memory/sessions/{project}/YYYY-MM-DD-{slug}.md
3. Format: Markdown with frontmatter (agent, date, session ID)
4. Index the new Markdown file into SQLite
```

**Frontmatter format**:
```markdown
---
session: ses_abc123
agent: sisyphus
date: 2026-02-16
title: Implement auth flow
project: /path/to/project
---

## User
How should we implement the auth flow?

## Assistant (sisyphus)
Based on the existing patterns...
```

**Delta detection**: Track last-harvested session timestamp. Only process sessions modified after that timestamp.

### D7: Auto-indexing — hybrid watcher + polling

**Decision**: Combine file watching (chokidar) with interval polling for robustness.

- **File watcher** (chokidar): Watches `~/.opencode-memory/` for Markdown file changes. Debounce 2 seconds.
- **Interval polling**: Every 5 minutes, scan all collections for changes via hash comparison.
- **Session polling**: Every 2 minutes, check OpenCode storage for new/modified sessions.
- **Dirty flag**: Set on file change, actual re-indexing happens on next search or scheduled interval.
- **Delta sync**: Compare file content hash against stored hash in `documents` table. Only re-chunk and re-embed changed files.

**Why both?** File watchers can miss events (editor temp files, network mounts). Polling catches what watchers miss. The combination is what OpenClaw uses.

### D8: MCP transport — stdio (default) + HTTP (daemon)

**Decision**: Support both transports, matching QMD.

- **Stdio** (default): `opencode-memory mcp` — launched as subprocess by OpenCode. Simple, no port management.
- **HTTP** (daemon): `opencode-memory mcp --http --port 8282` — shared long-lived server. Models stay loaded in VRAM across requests.
- **Daemon mode**: `opencode-memory mcp --http --daemon` — background process with PID file.

**OpenCode config** (stdio):
```json
{
  "mcp": {
    "opencode-memory": {
      "type": "local",
      "command": ["opencode-memory", "mcp"],
      "enabled": true
    }
  }
}
```

**Why 8282?** QMD uses 8181. We use 8282 to avoid conflicts if both are running.

### D9: Memory layers — 3-tier (adapted from OpenClaw)

**Decision**: Three memory tiers, all stored as Markdown:

| Tier | Path | Behavior |
|------|------|----------|
| Long-term | `~/.opencode-memory/MEMORY.md` | Curated facts, loaded into search index |
| Daily logs | `~/.opencode-memory/memory/YYYY-MM-DD.md` | Append-only daily context |
| Sessions | `~/.opencode-memory/sessions/{project}/YYYY-MM-DD-{slug}.md` | Auto-harvested from OpenCode |

**`memory_write` tool** allows agents to write to MEMORY.md or daily logs directly. Sessions are auto-harvested.

### D10: Project location

**Decision**: New repository at `~/workspaces/self/AI/Tools/opencode-memory/` (sibling to ai-sandbox-wrapper and opencode-mcp-manager).

**Why sibling, not subdirectory?** It's a standalone npm package with its own dependencies, CI, and release cycle. Nesting it inside ai-sandbox-wrapper would conflate concerns.

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|------|--------|------------|
| ~2GB model download on first use | Poor first-run experience | Show progress bar, download in background, cache permanently |
| node-llama-cpp native compilation | Build failures on some platforms | Provide pre-built binaries, fallback to BM25-only mode if models fail |
| SQLite locking with concurrent access | Corruption if multiple processes write | WAL mode, single-writer design, MCP server is the sole writer |
| Session harvester reads OpenCode internals | Breaks if OpenCode changes storage format | Version-detect storage format, graceful degradation if format unknown |
| VRAM usage (~2GB for all 3 models) | May not fit on low-end machines | Lazy model loading (only load reranker/expander for `memory_query`), CPU fallback |
| Stale index after crash | Missing recent memories | Startup integrity check, re-index on hash mismatch |

## Open Questions

1. **Should `memory_write` auto-trigger reindex?** Or batch writes and reindex on next search? (Leaning: immediate for MEMORY.md, batched for daily logs)
2. **Session harvesting granularity**: Harvest entire sessions as one document, or split by conversation turns? (Leaning: one document per session, chunker handles splitting)
3. **Model fallback**: If GGUF models fail to load, should we fall back to BM25-only or error out? (Leaning: BM25-only with warning)
4. **Cross-project memory**: Should MEMORY.md be global or per-project? (Leaning: per-project with optional global collection)
