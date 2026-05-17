## ADDED Requirements

### Requirement: Watch OpenCode Session Storage

The system SHALL watch `~/.local/share/opencode/storage/` for new and modified session files. The watcher SHALL detect changes to session metadata files (`ses_*.json`).

#### Scenario: Detect new session files

- **WHEN** a new file `ses_abc123.json` is created in the session directory
- **THEN** the system SHALL detect the new session and SHALL trigger harvesting

#### Scenario: Detect modified session files

- **WHEN** an existing session file `ses_abc123.json` is modified
- **THEN** the system SHALL detect the modification and SHALL re-harvest the session

### Requirement: Parse Session Metadata

The system SHALL parse session metadata from `ses_*.json` files to extract session ID, slug, title, timestamps, and project directory.

#### Scenario: Extract session ID and slug

- **WHEN** parsing `ses_abc123.json` with `{"id": "ses_abc123", "slug": "implement-auth"}`
- **THEN** the system SHALL extract session ID "ses_abc123" and slug "implement-auth"

#### Scenario: Extract title and timestamps

- **WHEN** parsing session metadata with `{"title": "Implement auth flow", "createdAt": "2026-02-16T10:00:00Z"}`
- **THEN** the system SHALL extract title "Implement auth flow" and created timestamp

#### Scenario: Extract project directory

- **WHEN** parsing session metadata with `{"projectPath": "/path/to/project"}`
- **THEN** the system SHALL extract project path "/path/to/project" for organizing harvested sessions

### Requirement: Parse Message Metadata

The system SHALL parse message metadata from `msg_*.json` files to extract role (user/assistant), agent name, and model information.

#### Scenario: Extract message role

- **WHEN** parsing `msg_001.json` with `{"role": "user"}`
- **THEN** the system SHALL extract role "user"

#### Scenario: Extract agent name for assistant messages

- **WHEN** parsing `msg_002.json` with `{"role": "assistant", "agent": "sisyphus"}`
- **THEN** the system SHALL extract agent name "sisyphus"

#### Scenario: Extract model information

- **WHEN** parsing message metadata with `{"model": "claude-3-5-sonnet-20241022"}`
- **THEN** the system SHALL extract model information for metadata

### Requirement: Parse Message Parts

The system SHALL parse message parts from `prt_*.json` files to extract text content. Synthetic parts (system prompts) SHALL be filtered out.

#### Scenario: Extract text from message parts

- **WHEN** parsing `prt_001.json` with `{"type": "text", "content": "How should we implement auth?"}`
- **THEN** the system SHALL extract the text content

#### Scenario: Filter out synthetic parts

- **WHEN** parsing a message part with `{"synthetic": true}`
- **THEN** the system SHALL exclude that part from the harvested content

#### Scenario: Concatenate multiple parts

- **WHEN** a message has 3 text parts
- **THEN** the system SHALL concatenate all non-synthetic parts into a single message body

### Requirement: Generate Markdown with YAML Frontmatter

The system SHALL generate Markdown files with YAML frontmatter containing session ID, agent name, date, title, and project path.

#### Scenario: YAML frontmatter format

- **WHEN** generating Markdown for session "ses_abc123"
- **THEN** the frontmatter SHALL include `session: ses_abc123`, `agent: sisyphus`, `date: 2026-02-16`, `title: Implement auth flow`, and `project: /path/to/project`

#### Scenario: Frontmatter delimiter

- **WHEN** generating Markdown
- **THEN** the frontmatter SHALL be enclosed in `---` delimiters at the start of the file

### Requirement: Format Conversation Sections

The system SHALL format conversations with `## User` and `## Assistant (agent)` section headers. Each message SHALL be a separate section.

#### Scenario: User message section

- **WHEN** formatting a user message "How should we implement auth?"
- **THEN** the system SHALL create a section `## User\nHow should we implement auth?`

#### Scenario: Assistant message section with agent name

- **WHEN** formatting an assistant message from agent "sisyphus"
- **THEN** the system SHALL create a section `## Assistant (sisyphus)\n{message content}`

#### Scenario: Multiple message turns

- **WHEN** a session has 5 user messages and 5 assistant messages
- **THEN** the system SHALL create 10 sections alternating between User and Assistant

### Requirement: Delta Detection

The system SHALL track the last-harvested timestamp for each session. Only sessions modified after the last-harvested timestamp SHALL be processed.

#### Scenario: Track last-harvested timestamp

- **WHEN** a session is successfully harvested
- **THEN** the system SHALL record the harvest timestamp in a state file

#### Scenario: Skip unchanged sessions

- **WHEN** scanning for sessions and a session's modified time is before the last-harvested timestamp
- **THEN** the system SHALL skip processing that session

#### Scenario: Process new sessions only

- **WHEN** 100 sessions exist and 3 are modified since last harvest
- **THEN** the system SHALL process only the 3 modified sessions

### Requirement: Output to Project-Specific Directory

The system SHALL output harvested Markdown files to `~/.opencode-memory/sessions/{project-hash}/YYYY-MM-DD-{slug}.md` where project-hash is derived from the project path.

#### Scenario: Project-specific subdirectory

- **WHEN** harvesting a session for project "/path/to/myapp"
- **THEN** the system SHALL create a subdirectory using a hash of "/path/to/myapp"

#### Scenario: Date-prefixed filename

- **WHEN** harvesting a session created on 2026-02-16 with slug "implement-auth"
- **THEN** the system SHALL create file `2026-02-16-implement-auth.md`

#### Scenario: Slug sanitization

- **WHEN** a session slug contains special characters or spaces
- **THEN** the system SHALL sanitize the slug to create a valid filename

### Requirement: Graceful Handling of Unknown Storage Formats

The system SHALL detect the OpenCode storage format version and SHALL gracefully handle unknown versions with a warning.

#### Scenario: Detect storage format version

- **WHEN** parsing session files
- **THEN** the system SHALL check for a version indicator in the JSON structure

#### Scenario: Warn on unknown format

- **WHEN** the storage format version is not recognized
- **THEN** the system SHALL display "⚠️ WARNING: Unknown OpenCode storage format. Session harvesting may be incomplete."

#### Scenario: Continue with best-effort parsing

- **WHEN** encountering an unknown storage format
- **THEN** the system SHALL attempt to parse using known field names and SHALL skip unrecognized fields

### Requirement: Polling Interval

The system SHALL poll the OpenCode storage directory every 2 minutes for new or modified sessions.

#### Scenario: 2-minute polling interval

- **WHEN** the session harvester is running
- **THEN** the system SHALL check for new/modified sessions every 2 minutes

#### Scenario: Immediate harvest on startup

- **WHEN** the session harvester starts
- **THEN** the system SHALL immediately scan for new sessions before starting the 2-minute polling interval
