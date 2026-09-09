## ADDED Requirements

### Requirement: Playwright host CDP mode
The base image build system SHALL support an `INSTALL_PLAYWRIGHT_HOST` environment variable that, when set to `1` AND when at least one MCP browser flag (`INSTALL_CHROME_DEVTOOLS_MCP` or `INSTALL_PLAYWRIGHT_MCP`) is also set to `1`, causes the MCP installation step to skip the container-side Chromium binary and its system libraries. The MCP npm packages SHALL still be installed; only the in-container browser binary is omitted.

#### Scenario: Host CDP mode with chrome-devtools-mcp
- **WHEN** `INSTALL_PLAYWRIGHT_HOST=1` AND `INSTALL_CHROME_DEVTOOLS_MCP=1` are set during base image build
- **THEN** the `chrome-devtools-mcp@latest` npm package SHALL be installed
- **AND** the Chromium binary SHALL NOT be downloaded into `/opt/playwright-browsers`
- **AND** the Chromium-specific system libraries (libnss3, libxcb1, libgbm1, ...) SHALL NOT be installed
- **AND** the resulting image SHALL be approximately 400 MB smaller than the non-host equivalent

#### Scenario: Host CDP mode with playwright-mcp
- **WHEN** `INSTALL_PLAYWRIGHT_HOST=1` AND `INSTALL_PLAYWRIGHT_MCP=1` are set during base image build
- **THEN** the `@playwright/mcp@latest` npm package SHALL be installed
- **AND** the marker file `/opt/.mcp-playwright-installed` SHALL be created
- **AND** no Chromium binary SHALL be installed in the container

#### Scenario: Host CDP mode without any MCP flag
- **WHEN** `INSTALL_PLAYWRIGHT_HOST=1` is set but both `INSTALL_CHROME_DEVTOOLS_MCP=0` and `INSTALL_PLAYWRIGHT_MCP=0`
- **THEN** `INSTALL_PLAYWRIGHT_HOST` SHALL have no effect on the image
- **AND** no MCP packages SHALL be installed

#### Scenario: Container-side Chromium mode (default)
- **WHEN** `INSTALL_PLAYWRIGHT_HOST=0` or unset AND at least one MCP flag is `1`
- **THEN** the shared Chromium binary SHALL be downloaded into `/opt/playwright-browsers`
- **AND** the symlink `/opt/chromium` SHALL point to the Chromium executable
- **AND** all required system libraries SHALL be installed via `apt-get`
- **AND** `PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers` SHALL be set in the image environment

### Requirement: Atlassian CLI support
The base image build system SHALL support optional installation of Atlassian CLI (`acli`) via the `INSTALL_ACLI` environment variable, using Atlassian's official Debian APT repository.

#### Scenario: ACLI installation enabled
- **WHEN** `INSTALL_ACLI=1` is set during base image build
- **THEN** the following SHALL be installed in the image:
  - `gnupg` (required for dearmoring Atlassian's ASCII-armored GPG key)
  - Atlassian's GPG key at `/etc/apt/keyrings/acli-archive-keyring.gpg`
  - APT source `https://acli.atlassian.com/linux/deb` at `/etc/apt/sources.list.d/acli.list`
  - The `acli` package via `apt-get install`

#### Scenario: ACLI installation disabled (default)
- **WHEN** `INSTALL_ACLI` is unset or set to `0`
- **THEN** no Atlassian CLI dependencies SHALL be installed
- **AND** the base image size SHALL remain unchanged

### Requirement: Datadog Pup CLI support
The base image build system SHALL support optional installation of Datadog Pup CLI via the `INSTALL_PUP` environment variable using a multi-stage Rust build, plus optional OpenCode skill bundling.

#### Scenario: Pup installation enabled
- **WHEN** `INSTALL_PUP=1` is set during base image build
- **THEN** a `rust:bookworm` builder stage SHALL compile `pup` via `cargo install --git https://github.com/DataDog/pup --locked`
- **AND** the resulting binary SHALL be copied to `/usr/local/bin/pup` in the final image
- **AND** the Rust toolchain SHALL NOT appear in the final image (discarded with the builder stage)
- **AND** if the `skills/dd-pup/SKILL.md` file exists in the repository, it SHALL be copied to `/home/agent/.config/opencode/skills/dd-pup/SKILL.md`

#### Scenario: Pup installation disabled (default)
- **WHEN** `INSTALL_PUP` is unset or set to `0`
- **THEN** no Pup binary or skill SHALL be installed
- **AND** no Rust builder stage SHALL run

### Requirement: Go toolchain support
The base image build system SHALL support optional installation of the Go 1.23 toolchain plus common Go developer tools via the `INSTALL_GO` environment variable.

#### Scenario: Go installation enabled
- **WHEN** `INSTALL_GO=1` is set during base image build
- **THEN** Go 1.23.0 SHALL be installed at `/usr/local/go`
- **AND** the following tools SHALL be installed to `/usr/local/bin`:
  - `sqlc@v1.30.0`
  - `goose@v3.24.3`
  - `golangci-lint v1.62.2`
- **AND** the following environment variables SHALL be set in the image:
  - `PATH=/usr/local/go/bin:/home/agent/go/bin:$PATH`
  - `GOPATH=/home/agent/go`
  - `GOTOOLCHAIN=local`

#### Scenario: Go installation disabled (default)
- **WHEN** `INSTALL_GO` is unset or set to `0`
- **THEN** no Go toolchain SHALL be installed
