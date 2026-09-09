# Change: Add Playwright Browser Automation Support

## Why
AI coding agents increasingly need browser automation capabilities for testing, web scraping, and UI verification. Currently, containers lack the system dependencies required to run Playwright browsers, causing failures when AI tools attempt browser-based operations.

## What Changes
- Add `playwright` to the **Additional Tools** menu in `setup.sh` (alongside spec-kit, ux-ui-promax, openspec)
- Add `INSTALL_PLAYWRIGHT` environment variable handling in `setup.sh`
- Add Playwright installation block in `lib/install-base.sh`:
  - Install system dependencies (libglib2.0, libnss3, libatk, libx11, etc.)
  - Install Playwright globally via pnpm
  - Install Playwright browsers (Chromium, Firefox, WebKit)

## Impact
- Affected specs: `base-image` (new capability spec)
- Affected code:
  - `setup.sh` (lines ~318, ~369-378, ~381)
  - `lib/install-base.sh` (new conditional block)
- Image size: ~500MB increase when Playwright enabled (browsers are large)
- Build time: ~2-3 minutes additional when enabled
- No breaking changes - opt-in only via interactive menu selection
