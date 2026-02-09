# base-image Specification

## Purpose
TBD - created by archiving change add-playwright-support. Update Purpose after archive.
## Requirements
### Requirement: Playwright Browser Automation Support
The base image build system SHALL support optional installation of Playwright and its browser dependencies via the `INSTALL_PLAYWRIGHT` environment variable.

#### Scenario: Playwright installation enabled
- **WHEN** `INSTALL_PLAYWRIGHT=1` is set during base image build
- **THEN** the following system dependencies SHALL be installed:
  - libglib2.0-0 (GLib library)
  - libnspr4, libnss3 (Network Security Services)
  - libdbus-1-3 (D-Bus IPC)
  - libatk1.0-0, libatk-bridge2.0-0 (Accessibility toolkit)
  - libcups2 (CUPS printing)
  - libxcb1, libxkbcommon0 (X11/Wayland support)
  - libatspi2.0-0 (Assistive Technology)
  - libx11-6, libxcomposite1, libxdamage1, libxext6, libxfixes3, libxrandr2 (X11 extensions)
  - libgbm1 (Graphics Buffer Manager)
  - libcairo2, libpango-1.0-0 (Graphics rendering)
  - libasound2 (ALSA audio)
- **AND** Playwright SHALL be installed globally via pnpm
- **AND** Playwright browsers (Chromium, Firefox, WebKit) SHALL be installed

#### Scenario: Playwright installation disabled (default)
- **WHEN** `INSTALL_PLAYWRIGHT` is not set or set to `0`
- **THEN** no Playwright dependencies SHALL be installed
- **AND** the base image size SHALL remain unchanged

#### Scenario: Playwright verification
- **WHEN** Playwright is installed in the container
- **THEN** running `pnpm exec playwright --version` SHALL succeed
- **AND** running `pnpm exec playwright install --dry-run` SHALL show browsers are available

### Requirement: Ruby Runtime Support
The base image build system SHALL support optional installation of Ruby runtime and Rails framework via the `INSTALL_RUBY` environment variable.

#### Scenario: Ruby installation enabled
- **WHEN** `INSTALL_RUBY=1` is set during base image build
- **THEN** the following Ruby build dependencies SHALL be installed:
  - libssl-dev (OpenSSL development files)
  - libreadline-dev (Readline library)
  - zlib1g-dev (Compression library)
  - libyaml-dev (YAML parsing)
  - libffi-dev (Foreign function interface)
  - libgdbm-dev (GNU database manager)
  - libncurses5-dev (Terminal handling)
- **AND** rbenv SHALL be installed for Ruby version management
- **AND** ruby-build plugin SHALL be installed for compiling Ruby
- **AND** Ruby 3.3.0 SHALL be installed and set as global default
- **AND** Rails 8.0.2 gem SHALL be installed
- **AND** Bundler gem SHALL be installed

#### Scenario: Ruby installation disabled (default)
- **WHEN** `INSTALL_RUBY` is not set or set to `0`
- **THEN** no Ruby dependencies SHALL be installed
- **AND** the base image size SHALL remain unchanged

#### Scenario: Ruby verification
- **WHEN** Ruby is installed in the container
- **THEN** running `ruby --version` SHALL show version 3.3.0
- **AND** running `rails --version` SHALL show version 8.0.2
- **AND** running `bundle --version` SHALL succeed
- **AND** running `gem --version` SHALL succeed

#### Scenario: Rails project creation
- **WHEN** Ruby and Rails are installed in the container
- **THEN** running `rails new myapp` SHALL successfully create a new Rails application
- **AND** the created application SHALL be runnable with `rails server`

### Requirement: Ripgrep File Search Support
The base image SHALL include the ripgrep (`rg`) binary to provide fast file search capabilities for AI tools that depend on it.

#### Scenario: Ripgrep binary available in container
- **WHEN** a container is started from an image built on ai-base
- **THEN** the `rg` command SHALL be available in PATH
- **AND** running `rg --version` SHALL succeed and display version information

#### Scenario: Ripgrep executes file search
- **WHEN** ripgrep is invoked with a search pattern and directory
- **THEN** it SHALL search files recursively and return matching results
- **AND** the search SHALL work regardless of host platform architecture

#### Scenario: OpenCode file search works in sandbox
- **WHEN** OpenCode's "@" file reference feature is used inside the container
- **THEN** file search SHALL succeed using the system ripgrep binary
- **AND** users SHALL be able to search and reference files by name or pattern

#### Scenario: Architecture-independent operation
- **WHEN** the container runs on Linux ARM64 (aarch64)
- **AND** the host mounts a macOS Mach-O ripgrep binary at `~/.local/share/opencode/bin/rg`
- **THEN** the system ripgrep at `/usr/bin/rg` SHALL be used instead
- **AND** no "Exec format error" SHALL occur during file search operations

