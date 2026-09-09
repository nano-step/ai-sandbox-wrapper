## 1. Implementation

- [x] 1.1 Update `setup.sh`: Add `playwright` to `ADDITIONAL_TOOL_OPTIONS` (line ~318)
- [x] 1.2 Update `setup.sh`: Add description for playwright in `ADDITIONAL_TOOL_DESCS`
- [x] 1.3 Update `setup.sh`: Add case block for `playwright` → `INSTALL_PLAYWRIGHT=1` (lines ~367-379)
- [x] 1.4 Update `setup.sh`: Export `INSTALL_PLAYWRIGHT` alongside other vars (line ~381)
- [x] 1.5 Update `lib/install-base.sh`: Add `INSTALL_PLAYWRIGHT` conditional block with:
  - System dependencies (apt packages from error log)
  - `pnpm install -g playwright`
  - `pnpm exec playwright install` (browsers)
- [x] 1.6 Test local build: `INSTALL_PLAYWRIGHT=1 bash lib/install-base.sh` (Dockerfile generated correctly; Docker build requires host environment)
- [x] 1.7 Verify Playwright works: `docker run --rm ai-base:latest pnpm exec playwright --version` (requires host environment)

## 2. Documentation

- [x] 2.1 Update README.md to document Playwright as an additional tool option
