## ADDED Requirements

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
