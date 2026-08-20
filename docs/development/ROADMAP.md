# Roadmap

The roadmap describes broad capability order. It is not a daily checklist and does not authorize an Agent to begin work. Current execution lives in `STATUS.md` and one active Task; confirmed work lives in Backlog; uncommitted possibilities live in Ideas.

## Now: unversioned incubation

The native application and three core vertical slices are implemented. The project owner is continuing product development before choosing the first public release. New work may be selected directly or from Ideas/Backlog, but every implementation still requires a bounded Task and normal acceptance.

Completed selection, screenshot, credential, latency, and memory evidence remains in `docs/development/VERIFICATION.md`. The unchecked items in the withdrawn `docs/versions/0.1.0/` draft are historical evidence gaps, not the current queue and not a ban on feature expansion.

No product release version is currently assigned. Version selection and a fresh release contract begin only when the project owner explicitly starts release preparation.

## Ongoing direction: strengthen the instantaneous translation layer

Potential incubation directions, subject to separate Tasks and product decisions:

- bounded on-demand context and user-controlled terminology;
- optional cloud structured OCR with explicit image-upload consent;
- compatibility and interaction improvements to current entry points;
- Provider capability and configuration evolution.

Accepted architectural directions appear in ADRs. Open questions and promotion conditions are in `docs/backlog/IDEAS.md`.

## Later: universal translation workspace

After the instantaneous layer is reliable, evaluate a separate main workspace for one document format at a time. PDF, Office, multipage OCR, batch processing, persistent jobs, and layout-preserving export require their own product and storage decisions.

## Future release preparation

When the project owner decides the product is ready, a release-preparation Task chooses the actual first version and creates a fresh contract from current facts. Developer ID signing, notarization, DMG packaging, updates, Intel support, and public distribution are considered only when that Task brings them into scope.
