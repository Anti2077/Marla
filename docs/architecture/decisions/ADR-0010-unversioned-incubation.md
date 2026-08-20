# ADR-0010: Unversioned incubation and release-time version assignment

Status: Accepted

Date: 2026-08-18

## Context

Marla used `0.1.0 Alpha` as both a development milestone and an eventual release label before the project owner considered the product ready for first publication. Product behavior, implementation notes, exclusions, acceptance evidence, App metadata, and release preparation became coupled to that provisional number. The result made an unfinished release draft behave like a scope freeze and steered ongoing development toward closing its checklist instead of continuing owner-selected product work.

A macOS App still requires numeric `CFBundleShortVersionString` and `CFBundleVersion` fields even when it is not a public release. Compatibility identifiers inside Rust, FFI, requests, storage, and migrations also remain necessary independently of product marketing versions.

## Decision

Marla will remain in `Incubation / Unreleased` with no assigned product release version until the project owner explicitly starts a release-preparation Task.

- Development Apps use `0.0.0` as a non-public Marketing Version sentinel. It is not a release name.
- Feature and fix Tasks do not increment a product version.
- The withdrawn `0.1.0` contract and release record remain historical drafts and do not constrain current incubation scope.
- A release-preparation Task chooses the actual version, creates a fresh contract from current facts, updates App metadata and verification, and defines distribution acceptance.
- After first publication, unpublished work accumulates under `Unreleased`; the next version is selected for the batch being released, not for each feature as it lands.
- Rust crate, C ABI, request schema, storage, and migration versions remain independent technical compatibility identifiers.

This decision changes scheduling and release bookkeeping only. It does not authorize any feature, repeal privacy boundaries, or supersede architecture decisions. In particular, the version-timing phrases in ADR-0002, ADR-0003, and ADR-0005 no longer schedule work relative to `0.1.0`; their substantive cloud-image, bounded-context, local-fallback, disclosure, and acceptance requirements remain in force until an explicit Task and ADR change them.

## Consequences

- Product exploration is no longer blocked by an arbitrary first-release checklist.
- Each new capability still needs explicit Task scope and normal verification.
- Current specifications must describe current behavior without using a provisional release number as the owner of that behavior.
- Release preparation becomes a deliberate phase with a version chosen from the actual batch and current evidence.
- The `0.0.0` development sentinel must never be published as a user-facing release.
- Historical `0.1.0` evidence remains useful, but it cannot be cited as current release readiness without fresh validation.
