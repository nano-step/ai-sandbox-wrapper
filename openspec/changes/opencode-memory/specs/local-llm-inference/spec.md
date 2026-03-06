## ADDED Requirements

### Requirement: Three-Model Architecture

The system SHALL manage three GGUF models: EmbeddingGemma-300M for embeddings, Qwen3-Reranker-0.6B for reranking, and Qwen3-1.7B for query expansion. Each model SHALL be loaded via node-llama-cpp.

#### Scenario: Load embedding model

- **WHEN** the system needs to generate embeddings
- **THEN** the system SHALL load EmbeddingGemma-300M-Q8_0 from cache or download from HuggingFace

#### Scenario: Load reranker model

- **WHEN** the system executes a `memory_query` hybrid search
- **THEN** the system SHALL load Qwen3-Reranker-0.6B-Q8_0 for cross-encoder reranking

#### Scenario: Load query expansion model

- **WHEN** the system executes a `memory_query` hybrid search
- **THEN** the system SHALL load qmd-query-expansion-1.7B-q4_k_m to generate 2 query variants

### Requirement: Auto-Download from HuggingFace

The system SHALL automatically download GGUF models from HuggingFace on first use. Downloads SHALL be cached at `~/.cache/opencode-memory/models/` and SHALL display progress indicators.

#### Scenario: First-time model download

- **WHEN** EmbeddingGemma-300M is needed but not cached
- **THEN** the system SHALL download from `hf:ggml-org/embeddinggemma-300M-GGUF` and SHALL display download progress

#### Scenario: Use cached models on subsequent runs

- **WHEN** a model exists in `~/.cache/opencode-memory/models/`
- **THEN** the system SHALL load from cache without downloading

#### Scenario: Download all three models totaling ~2GB

- **WHEN** all three models are downloaded for the first time
- **THEN** the total disk usage SHALL be approximately 2GB (300MB + 640MB + 1.1GB)

### Requirement: Model Caching

The system SHALL cache downloaded models at `~/.cache/opencode-memory/models/` with subdirectories per model. Cached models SHALL persist across sessions.

#### Scenario: Persistent model cache

- **WHEN** a model is downloaded and the system restarts
- **THEN** the system SHALL reuse the cached model without re-downloading

#### Scenario: Cache directory structure

- **WHEN** models are cached
- **THEN** the cache SHALL contain subdirectories `embeddinggemma-300M/`, `qwen3-reranker-0.6B/`, and `qmd-query-expansion-1.7B/`

### Requirement: Lazy Model Loading

The system SHALL load models lazily only when needed. The reranker and query expansion models SHALL only be loaded for `memory_query` calls, not for `memory_search` or `memory_vsearch`.

#### Scenario: Skip reranker for BM25-only search

- **WHEN** a user calls `memory_search` (BM25 only)
- **THEN** the system SHALL NOT load the reranker or query expansion models

#### Scenario: Load reranker only for hybrid search

- **WHEN** a user calls `memory_query` (hybrid search)
- **THEN** the system SHALL load the reranker and query expansion models

#### Scenario: Embedding model loaded on first index or search

- **WHEN** the system needs to embed a query or document for the first time
- **THEN** the system SHALL load EmbeddingGemma-300M and SHALL keep it loaded for subsequent operations

### Requirement: Batch Embedding Support

The system SHALL support batch embedding via `embedBatch` method to process multiple chunks in a single call. Batch size SHALL be configurable based on available VRAM/CPU.

#### Scenario: Batch embed multiple chunks

- **WHEN** indexing a document with 10 chunks
- **THEN** the system SHALL call `embedBatch` with all 10 chunks instead of 10 individual `embed` calls

#### Scenario: Configurable batch size

- **WHEN** VRAM is limited
- **THEN** the system SHALL reduce batch size to avoid out-of-memory errors

### Requirement: Parallel Contexts for Embedding and Reranking

The system SHALL support parallel embedding and reranking contexts based on available VRAM/CPU. Multiple contexts SHALL process chunks concurrently to reduce latency.

#### Scenario: Parallel embedding contexts

- **WHEN** sufficient VRAM is available
- **THEN** the system SHALL create multiple embedding contexts to process chunks in parallel

#### Scenario: Sequential fallback for low resources

- **WHEN** VRAM is insufficient for parallel contexts
- **THEN** the system SHALL fall back to sequential processing with a single context

### Requirement: Graceful Fallback to BM25-Only

The system SHALL gracefully fall back to BM25-only search if GGUF models fail to load. A warning SHALL be displayed to the user indicating degraded search quality.

#### Scenario: Model load failure fallback

- **WHEN** EmbeddingGemma-300M fails to load due to missing dependencies
- **THEN** the system SHALL display a warning and SHALL execute `memory_query` as BM25-only search

#### Scenario: Warning message for degraded mode

- **WHEN** falling back to BM25-only mode
- **THEN** the system SHALL display "⚠️ WARNING: Vector search unavailable, using BM25 only. Search quality may be reduced."

### Requirement: Prompt Formats for Embeddings

The system SHALL use task-specific prompt formats for embeddings: `"task: search result | query: {query}"` for query embeddings and `"title: {title} | text: {content}"` for document embeddings.

#### Scenario: Query embedding prompt

- **WHEN** embedding a user query "authentication flow"
- **THEN** the system SHALL format the prompt as `"task: search result | query: authentication flow"`

#### Scenario: Document embedding prompt

- **WHEN** embedding a document chunk with title "Auth Implementation"
- **THEN** the system SHALL format the prompt as `"title: Auth Implementation | text: {chunk_content}"`
