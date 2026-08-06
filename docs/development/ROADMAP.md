# Roadmap

The roadmap describes broad capability order. It is not a daily checklist and does not authorize an Agent to begin work. Current execution lives in `STATUS.md` and one active Task; confirmed work lives in Backlog; uncommitted possibilities live in Ideas.

## Now: 0.1.0 Alpha acceptance

The native application and three vertical slices are implemented. The remaining phase is evidence, not feature expansion:

- representative cross-application selection compatibility;
- real screenshot crop and permission persistence;
- latency and memory measurement;
- all remaining non-Force-Touch acceptance checks.

The complete contract is under `docs/versions/0.1.0/`; executable candidates are listed as BL-001 through BL-004.

## Next: strengthen the instantaneous translation layer

Potential directions after 0.1.0, subject to separate Tasks and product decisions:

- bounded on-demand context and user-controlled terminology;
- optional cloud structured OCR with explicit image-upload consent;
- compatibility and interaction improvements to current entry points;
- investigation of precise in-place presentation with honest fallback;
- Provider capability and configuration evolution.

Accepted architectural directions appear in ADRs. Open questions and promotion conditions are in `docs/backlog/IDEAS.md`.

## Later: universal translation workspace

After the instantaneous layer is reliable, evaluate a separate main workspace for one document format at a time. PDF, Office, multipage OCR, batch processing, persistent jobs, and layout-preserving export require their own product and storage decisions.

## Release engineering

Developer ID signing, notarization, DMG packaging, updates, Intel support, and public distribution are considered only when an owner-selected release Task brings them into scope.
