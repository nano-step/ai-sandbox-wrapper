## ADDED Requirements

### Requirement: Snippet extraction from install scripts
Each `install-{tool}.sh` script SHALL expose a `dockerfile_snippet()` function that outputs the Dockerfile `RUN` lines needed to install that tool, without triggering a `docker build`.

#### Scenario: Sourcing install script in snippet mode
- **WHEN** `SNIPPET_MODE=1` is set and `install-gemini.sh` is sourced
- **THEN** the `dockerfile_snippet` function SHALL be available
- **AND** no Docker image SHALL be built
- **AND** no directories SHALL be created on the host

#### Scenario: Snippet output format
- **WHEN** `dockerfile_snippet` is called for any tool
- **THEN** the output SHALL be valid Dockerfile syntax (RUN, USER, ENV, COPY lines)
- **AND** the output SHALL assume `FROM ai-base:latest` context (base packages available)
- **AND** the output SHALL install the tool binary to `/usr/local/bin/{tool}` or a symlinked equivalent

#### Scenario: Legacy standalone mode preserved
- **WHEN** `install-{tool}.sh` is executed directly (without `SNIPPET_MODE=1`)
- **THEN** the script SHALL behave exactly as before (generate Dockerfile, build image)
- **AND** backward compatibility SHALL be maintained

### Requirement: Unified Dockerfile composition
A build script (`lib/build-sandbox.sh`) SHALL compose a single Dockerfile from the base image preamble and selected tool snippets, then build one `ai-sandbox:latest` image.

#### Scenario: Building with multiple tools selected
- **WHEN** `build-sandbox.sh` is invoked with tools "claude,opencode,gemini"
- **THEN** a single `dockerfiles/sandbox/Dockerfile` SHALL be generated
- **AND** the Dockerfile SHALL start with the base image layers (from `install-base.sh` logic)
- **AND** the Dockerfile SHALL include the snippet from each selected tool in sequence
- **AND** the Dockerfile SHALL end with `USER agent` and `CMD ["bash"]`
- **AND** `docker build` SHALL produce `ai-sandbox:latest`

#### Scenario: Building with no tools selected
- **WHEN** `build-sandbox.sh` is invoked with an empty tool list
- **THEN** the script SHALL exit with an error message: "No tools selected"
- **AND** no image SHALL be built

#### Scenario: Building with enhancement tools and MCP flags
- **WHEN** `build-sandbox.sh` is invoked with tools "opencode" and flags `INSTALL_RTK=1 INSTALL_PLAYWRIGHT_MCP=1`
- **THEN** the base image section SHALL include RTK and Playwright MCP installation
- **AND** the opencode tool snippet SHALL be appended after the base section
- **AND** the resulting image SHALL contain both the base enhancements and the tool

### Requirement: Tool snippet validation
The build script SHALL validate each tool snippet before composing the final Dockerfile.

#### Scenario: Invalid snippet detected
- **WHEN** a tool's `dockerfile_snippet` function outputs invalid Dockerfile syntax
- **THEN** the build script SHALL report which tool's snippet failed
- **AND** the build script SHALL offer to skip the failing tool and continue

#### Scenario: All snippets valid
- **WHEN** all selected tools produce valid snippets
- **THEN** the build SHALL proceed without interruption

### Requirement: Image naming
The unified image SHALL be named `ai-sandbox:latest`.

#### Scenario: Local build naming
- **WHEN** the image is built locally via `build-sandbox.sh`
- **THEN** the image SHALL be tagged `ai-sandbox:latest`

#### Scenario: Registry build naming
- **WHEN** the image is built for the GitLab registry
- **THEN** the image SHALL be tagged `registry.gitlab.com/kokorolee/ai-sandbox-wrapper/ai-sandbox:latest`

### Requirement: Tool selection persistence
The build script SHALL save the list of installed tools to `~/.ai-sandbox/config.json` under `tools.installed`.

#### Scenario: Saving installed tools after build
- **WHEN** `build-sandbox.sh` successfully builds with tools "claude,opencode"
- **THEN** `~/.ai-sandbox/config.json` SHALL contain `"tools": {"installed": ["claude", "opencode"]}`

#### Scenario: Reading installed tools
- **WHEN** `ai-run` starts and reads `config.json`
- **THEN** it SHALL know which tools are available in the image
- **AND** it SHALL use this for help text and validation
