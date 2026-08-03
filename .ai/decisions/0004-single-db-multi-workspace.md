# ADR 0004: Single SQLite database with workspaceId isolation

- Status: Accepted
- Date: 2026-08-03
- Supersedes: physical per-workspace file expectation in architecture V1.1 §2 (logical isolation retained)

## Context

Architecture V1.1 described one SQLite file per workspace via `databasePath`. The implementation stores `databasePath` but opens a single app-level Drift database (`memos_one.sqlite`) and scopes all rows with `workspaceId`.

Multi-file DBs increase connection management, migration cost, and FTS complexity for little V1 gain.

## Decision

**V1 uses one SQLite database for all workspaces.** Isolation is logical via `workspaceId` on memo/tag/sync/attachment rows. `Workspace.databasePath` remains as a reserved field for a possible future multi-file mode or export path, not as the active SoT handle.

## Consequences

- Simpler migrations and backup of one file
- Workspace delete = DELETE WHERE workspace_id = ?
- Cross-workspace leakage risk if queries forget workspace filter (must be reviewed in repositories)
- Architecture docs should reference this ADR

## Alternatives considered

1. True multi-file Drift connections — deferred to post-V1 if encryption-per-workspace or export packaging requires it.
