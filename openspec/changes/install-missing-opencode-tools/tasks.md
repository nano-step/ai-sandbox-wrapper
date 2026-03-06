## 1. Dockerfile Changes

- [x] 1.1 Add `fd-find`, `sqlite3`, `poppler-utils`, `qpdf`, `tesseract-ocr` to apt-get in `dockerfiles/base/Dockerfile`
- [x] 1.2 Add `pip3 install` for Python PDF packages in `dockerfiles/base/Dockerfile`
- [x] 1.3 Add `pyright` and `vscode-langservers-extracted` to npm LSP line in `dockerfiles/base/Dockerfile`
- [x] 1.4 Mirror all changes in `dockerfiles/sandbox/Dockerfile`

## 2. Template Update

- [x] 2.1 Update `lib/install-base.sh` apt-get heredoc with new system packages
- [x] 2.2 Add pip3 install block to `lib/install-base.sh` template
- [x] 2.3 Update npm LSP line in `lib/install-base.sh` template

## 3. Verification

- [x] 3.1 Verify Dockerfile syntax consistency between base and sandbox
- [x] 3.2 Verify install-base.sh template matches Dockerfile patterns
