## ADDED Requirements

### Requirement: Smart Chunking with Scored Break Points

The system SHALL chunk markdown documents targeting 900 tokens per chunk with 15% overlap. Break points SHALL be scored based on semantic boundaries: H1=100, H2=90, H3=80, code fence=80, horizontal rule=60, blank line=20, list item=5, line break=1.

#### Scenario: Target 900-token chunks

- **WHEN** indexing a 5,000-token markdown document
- **THEN** the system SHALL produce approximately 5-6 chunks each targeting 900 tokens

#### Scenario: Scored break point selection

- **WHEN** approaching the 900-token target within a 200-token window
- **THEN** the system SHALL score each potential break point using `finalScore = baseScore × (1 - (distance/window)² × 0.7)` and SHALL cut at the highest-scoring break point

#### Scenario: 15% overlap between chunks

- **WHEN** creating consecutive chunks
- **THEN** each chunk SHALL overlap with the previous chunk by approximately 135 tokens (15% of 900)

### Requirement: Code Fence Protection

The system SHALL never split chunks inside code fences (triple backtick blocks). If a code fence spans the target cut point, the system SHALL extend the chunk to include the complete code block.

#### Scenario: Preserve complete code blocks

- **WHEN** a code fence starts at token 800 and ends at token 1100 in a chunk targeting 900 tokens
- **THEN** the system SHALL extend the chunk to token 1100 to include the complete code block

#### Scenario: Detect code fence boundaries

- **WHEN** scanning for break points
- **THEN** the system SHALL track code fence state (inside/outside) and SHALL assign score 0 to any break point inside a code fence

### Requirement: Content-Addressable Storage

The system SHALL store document content in a content-addressable manner using SHA-256 hashes. The `content` table SHALL use hash as primary key, and the `documents` table SHALL reference content by hash.

#### Scenario: Hash-based content deduplication

- **WHEN** two documents have identical content
- **THEN** the system SHALL store the content once in the `content` table and SHALL reference it from both document records

#### Scenario: SHA-256 hash generation

- **WHEN** storing a document
- **THEN** the system SHALL compute SHA-256 hash of the document body and SHALL use it as the content table primary key

### Requirement: Document Deduplication

The system SHALL detect duplicate documents by comparing content hashes. If a document with the same hash already exists, the system SHALL skip re-indexing and SHALL reuse existing embeddings.

#### Scenario: Skip re-indexing unchanged documents

- **WHEN** re-indexing a file whose content hash matches the stored hash
- **THEN** the system SHALL skip chunking, embedding, and FTS5 indexing for that document

#### Scenario: Update metadata for moved files

- **WHEN** a file is moved but content is unchanged
- **THEN** the system SHALL update the path in the `documents` table but SHALL reuse the existing content hash and embeddings

### Requirement: FTS5 Full-Text Index

The system SHALL create an FTS5 virtual table `documents_fts` with columns for filepath, title, and body. Tokenization SHALL use porter stemming and unicode61.

#### Scenario: FTS5 index creation

- **WHEN** initializing the database
- **THEN** the system SHALL create `documents_fts` virtual table with `tokenize='porter unicode61'`

#### Scenario: Index document chunks in FTS5

- **WHEN** a document is chunked into 5 pieces
- **THEN** the system SHALL insert 5 rows into `documents_fts` with filepath, title, and chunk body

### Requirement: sqlite-vec Vector Storage

The system SHALL create a sqlite-vec virtual table `vectors_vec` with 384-dimensional float embeddings using cosine distance metric. Primary key SHALL be `hash_seq` (content hash + chunk sequence number).

#### Scenario: Vector table initialization

- **WHEN** initializing the database
- **THEN** the system SHALL create `vectors_vec` virtual table with `embedding float[384] distance_metric=cosine`

#### Scenario: Store chunk embeddings

- **WHEN** a document chunk is embedded
- **THEN** the system SHALL insert a row into `vectors_vec` with `hash_seq` as `{content_hash}:{seq}` and the 384-dimensional embedding vector

### Requirement: Delta-Based Incremental Sync

The system SHALL implement delta-based sync by comparing file content hashes against stored hashes in the `documents` table. Only files with changed hashes SHALL be re-indexed.

#### Scenario: Detect changed files by hash

- **WHEN** scanning a collection for updates
- **THEN** the system SHALL compute SHA-256 hash of each file and SHALL compare it against the stored hash in the `documents` table

#### Scenario: Re-index only changed files

- **WHEN** 100 files are scanned and 3 have changed hashes
- **THEN** the system SHALL re-index only the 3 changed files and SHALL skip the 97 unchanged files

#### Scenario: Remove deleted files from index

- **WHEN** a file exists in the `documents` table but no longer exists on disk
- **THEN** the system SHALL set `active=0` for that document record

### Requirement: Embedding Cache

The system SHALL cache embeddings by content hash. When a document with the same content hash is re-indexed, the system SHALL reuse existing embeddings from `content_vectors` table.

#### Scenario: Reuse embeddings for duplicate content

- **WHEN** a document with hash `abc123` is indexed and later another document with the same hash is indexed
- **THEN** the system SHALL reuse the embeddings from `content_vectors` where `hash='abc123'`

#### Scenario: Skip embedding generation for cached content

- **WHEN** re-indexing a file whose content hash exists in `content_vectors`
- **THEN** the system SHALL skip calling the embedding model and SHALL copy vectors from the cache

### Requirement: Collection Management

The system SHALL support adding, removing, and listing collections. Each collection SHALL have a name, path, glob pattern (default `**/*.md`), and optional context annotation.

#### Scenario: Add collection with glob pattern

- **WHEN** a user adds collection "docs" with path "/path/to/docs" and pattern "**/*.md"
- **THEN** the system SHALL insert a row into the `collections` table and SHALL index all matching markdown files

#### Scenario: Remove collection

- **WHEN** a user removes collection "docs"
- **THEN** the system SHALL set `active=0` for all documents in that collection and SHALL remove the collection from the `collections` table

#### Scenario: List active collections

- **WHEN** a user requests collection list
- **THEN** the system SHALL return all rows from the `collections` table with name, path, pattern, and context fields
