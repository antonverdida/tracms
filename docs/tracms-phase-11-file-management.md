# TRACMS Phase 11 File Management

## Purpose

Handle certificate generation and document storage in a traceable, production-safe way.

## Certificate Needs

- [ ] PDF generation
- [ ] template storage
- [ ] QR generation

## Recommended Capabilities

- generate final certificate PDFs from approved data
- store reusable certificate templates separately from generated files
- attach QR codes or verification tokens to issued certificates
- keep immutable issuance metadata in the database

## Candidate Libraries And Approaches

- `pdf_generator`
- `qr_code`
- HTML-to-PDF rendering with a browser-backed tool if layout fidelity becomes critical

`earmark` is only needed if Markdown-to-HTML authoring becomes part of template editing.

## Storage Guidance

- use local storage only for development
- plan object storage for production certificate files and uploaded templates
- keep a stable database reference to each generated artifact

## Phase Exit Criteria

Phase 11 is complete when:

- certificates can be generated from real training data
- each issued certificate is traceable and verifiable
- storage strategy is safe for deployed environments
