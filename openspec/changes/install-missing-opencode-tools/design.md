## Context

The sandbox containers use `node:22-bookworm-slim` (Debian Bookworm). System packages are installed via a single `apt-get install` line. npm globals are installed via `npm install -g`. Python is available but no pip packages are pre-installed. Both `dockerfiles/base/Dockerfile` and `dockerfiles/sandbox/Dockerfile` must stay in sync, and `lib/install-base.sh` is the template generator for the base Dockerfile.

## Goals / Non-Goals

**Goals:**
- Install fd-find, sqlite3, and PDF system tools via apt-get
- Install Python PDF packages via pip3
- Install pyright and vscode-langservers-extracted via npm
- Update all three files (base Dockerfile, sandbox Dockerfile, install-base.sh template)

**Non-Goals:**
- Go LSP (gopls) — Go runtime not in base image
- Ruby LSP (solargraph) — Ruby not in base image
- MCP server pre-installation — handled by npx at runtime

## Decisions

### Add system packages to existing apt-get line
**Decision**: Append `fd-find`, `sqlite3`, `poppler-utils`, `qpdf`, `tesseract-ocr` to the existing apt-get install command.
**Rationale**: Follows existing single-layer pattern. No new RUN needed.

### Add Python PDF packages as separate RUN
**Decision**: Add `RUN pip3 install --no-cache-dir --break-system-packages pypdf pdfplumber reportlab pytesseract pdf2image` as a new layer after the apt-get block.
**Rationale**: pip install is a separate concern from apt-get. `--break-system-packages` is required on Debian Bookworm. `--no-cache-dir` keeps image small.

### Extend existing npm LSP line
**Decision**: Add `pyright` and `vscode-langservers-extracted` to the existing `npm install -g typescript typescript-language-server` line.
**Rationale**: Keeps all LSP tools in one layer. No new RUN needed.

## Risks / Trade-offs

- **Image size increase (~80-100MB)**: Acceptable given the functionality unlocked (PDF processing, Python/web diagnostics).
- **tesseract-ocr pulls in data files**: The `tesseract-ocr` package includes English language data. Other languages would need `tesseract-ocr-{lang}` packages — not included to keep size down.
