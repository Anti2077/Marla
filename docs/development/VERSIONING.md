# Versioning and Release Workflow

## Current state

Marla is in `Incubation / Unreleased`. There is no active public release target and no active release contract.

This state is intentional: the project owner is still shaping the product and may select additional feature Tasks before deciding that Marla is ready for its first public release. The withdrawn `0.1.0` draft does not freeze current scope.

## The three separate identifiers

| Identifier | Current value | Purpose | Change rule |
| --- | --- | --- | --- |
| Product release version | Unassigned | Names an actual public release | Assign only in an owner-authorized release-preparation Task |
| macOS development Marketing Version | `0.0.0` | Required numeric `CFBundleShortVersionString` for non-public test Apps | Keep as the development sentinel until release preparation |
| Build number | `1` | Required `CFBundleVersion` technical build identifier | May be automated later; it is not a product release promise |

Rust crate versions, C ABI versions, request `schemaVersion` values, migration versions, and data-format versions are compatibility identifiers. They do not announce a Marla product release and do not follow this document's product-version timing.

## Incubation workflow

During incubation:

1. The project owner selects a feature, fix, experiment, verification item, or documentation change directly or from Ideas/Backlog.
2. The work receives one explicit Task with scope, exclusions, acceptance, and verification.
3. Current product, feature, architecture, ADR, code, tests, and `STATUS.md` are updated as appropriate.
4. The development App remains `0.0.0`; completing or integrating a feature does not increment a product version.
5. There is no requirement to close every unchecked item in the withdrawn `0.1.0` acceptance draft before choosing new product work.

Incubation is not scope-free development. A Task still authorizes one bounded conversation, Accepted ADRs still control durable privacy and architecture decisions, and new subsystems or risky product changes still require the normal decision process.

## Starting the first release

Only an explicit project-owner request such as “prepare the first public release” starts release preparation. That Task must:

1. choose the actual SemVer product version;
2. create a fresh `docs/versions/<version>/` release contract from current code, specifications, known risks, and desired first-release scope;
3. set Xcode's Marketing Version and the App verification expectation to that chosen version;
4. create a `docs/releases/<version>.md` record with status `Preparing`;
5. define signing, packaging, notarization, distribution, rollback, acceptance, and real-device evidence required for that release;
6. publish only after every required release gate is satisfied and the project owner explicitly authorizes publication.

No version number is reserved merely because a feature exists, a Task completes, or a development App is built. A withdrawn or cancelled release draft does not count as a published version; its number may be selected again only through a new release-preparation decision and fresh evidence.

## After the first public release

After a real public release:

- completed but unpublished changes accumulate under `Unreleased` rather than changing the product version per feature;
- a release-preparation Task chooses the next version based on the complete batch being shipped;
- patch releases contain compatible fixes and small corrections;
- minor releases contain backward-compatible product capabilities;
- major releases are reserved for intentionally incompatible product or contract changes;
- while the public version remains below `1.0.0`, any compatibility break must still be called out explicitly even if SemVer permits more latitude.

At release time, the chosen version is applied once across Xcode metadata, verification expectations, release contract, release record, tags, packaged artifacts, and update metadata. Version changes are release operations, not daily development bookkeeping.

## Withdrawn 0.1.0 draft

`docs/versions/0.1.0/` and `docs/releases/0.1.0.md` describe a release draft that was never accepted or published. They are retained for historical product and verification evidence only.

Their unchecked acceptance items are not current blockers, their Out of Scope sections do not prohibit an owner-selected incubation Task, and their version-specific scheduling language does not override current Product, Feature, Architecture, ADR, Task, code, test, or `STATUS.md` facts.
