## Why

OpenCode agents inside the sandbox are missing several tools that their skills and built-in features depend on. An audit of OpenCode's tool integrations vs what's installed in the sandbox revealed these gaps:

1. **No file finder** — `fd-find` is faster and simpler than `find`, used heavily by agents
2. **No SQLite CLI** — OpenCode stores sessions in SQLite; agents can't inspect `.sqlite` files
3. **PDF skill broken** — The PDF skill requires `poppler-utils`, `qpdf`, `tesseract-ocr` (system) and `pypdf`, `pdfplumber`, `reportlab`, `pytesseract`, `pdf2image` (Python)
4. **Missing LSP servers** — Only TypeScript LSP is installed. Python (`pyright`) and HTML/CSS/JSON (`vscode-langservers-extracted`) LSPs are missing, so `diagnostics` tool returns nothing for those languages

## What Changes

- Add system packages to the base apt-get install: `fd-find`, `sqlite3`, `poppler-utils`, `qpdf`, `tesseract-ocr`
- Add Python PDF packages via pip: `pypdf`, `pdfplumber`, `reportlab`, `pytesseract`, `pdf2image`
- Add LSP servers via npm: `pyright`, `vscode-langservers-extracted`
- Mirror all changes in both `dockerfiles/base/Dockerfile` and `dockerfiles/sandbox/Dockerfile`
- Update `lib/install-base.sh` template to include the new packages

## Capabilities

### New Capabilities

- `pdf-processing`: System and Python tools for PDF text extraction, table parsing, OCR, and PDF creation
- `python-lsp`: Pyright LSP server for Python type checking and diagnostics
- `web-lsp`: HTML/CSS/JSON LSP servers for web development diagnostics

### Modified Capabilities

- `base-image`: Adding fd-find, sqlite3, and PDF system tools to apt-get; adding LSPs to npm globals; adding Python PDF packages

## Impact

- **Dockerfiles**: `dockerfiles/base/Dockerfile`, `dockerfiles/sandbox/Dockerfile`, `lib/install-base.sh`
- **Image size**: ~80-100MB increase (tesseract-ocr is the largest at ~30MB, pyright ~40MB)
- **Security**: No new attack surface — all tools are read/process-only utilities
- **CI**: Images need rebuild
