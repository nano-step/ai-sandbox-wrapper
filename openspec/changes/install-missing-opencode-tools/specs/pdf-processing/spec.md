## ADDED Requirements

### Requirement: PDF system tools available
The base and sandbox container images SHALL include `poppler-utils`, `qpdf`, and `tesseract-ocr` as pre-installed system packages.

#### Scenario: PDF text extraction works
- **WHEN** a container is started from the base or sandbox image
- **THEN** `pdftotext`, `pdfinfo`, `qpdf`, and `tesseract` SHALL be available in the system PATH

### Requirement: Python PDF libraries available
The base and sandbox container images SHALL have `pypdf`, `pdfplumber`, `reportlab`, `pytesseract`, and `pdf2image` installed via pip.

#### Scenario: Python PDF imports succeed
- **WHEN** a Python script runs `import pypdf, pdfplumber, reportlab, pytesseract, pdf2image`
- **THEN** all imports SHALL succeed without ImportError
