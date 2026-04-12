# ADR-001: Local Migrations via ArcadeDB Console (Flyway Retained for Central)

## Status
Superseded by [ADR-002](002-complete-flyway-removal.md)

## Date
2026-04-12

## Context

nomographic currently uses Flyway for both database targets:

- central server database (`central/sql/`)
- local embedded database (`local/sql/`)

For local embedded usage, this introduces avoidable operational coupling to
Flyway tooling. The project goal is to keep nomographic self-contained and make
local schema migration runnable with ArcadeDB-native tooling only.

At the same time, central server migrations already follow a stable Flyway flow
that supports validation and operational controls expected in server
infrastructure.

## Decision

Adopt a split migration strategy:

- Central target continues using Flyway with `central/flyway.toml`.
- Local target migrates to an ArcadeDB console-driven runner that:
  - discovers `local/sql/V*__*.sql`
  - executes scripts in version order
  - records applied versions for idempotency and recovery
  - supports dry-run/info style reporting for diagnostics

Implemented as:

- `scripts/migrate.sh central [migrate|validate|info]` for central Flyway
- `scripts/migrate-local.sh [migrate|validate|info]` for local migrations
- `SchemaMigration` metadata records in `nomon_local` with checksum tracking

## Rationale

- Reduces local deployment dependency surface.
- Aligns local migrations with ArcadeDB embedded runtime model.
- Preserves existing central operational process and compatibility.
- Keeps migration logic and operational scripts contained in nomographic.

## Consequences

Positive:

- Local setup no longer requires Flyway installation or Flyway Docker fallback.
- Local migration execution can be made deterministic with project-owned logic.
- Reduced mismatch risk between local embedded path handling and JDBC wrappers.

Trade-offs:

- nomographic must own migration ordering, state tracking, and idempotency
  checks previously delegated to Flyway for local.
- Additional script validation and test coverage are required.

## Implementation Notes

- Introduce a dedicated local migration script path under `scripts/`.
- Keep central `migrate.sh` behavior stable for Flyway users.
- Update `init-db.sh` to dispatch local migrations through console runner.
- Update README and architecture docs to document the split workflow.
- Add rollback procedure for partial local migration failures.

Implementation completed on 2026-04-12.

## Verification Requirements

- Fresh local database migration succeeds end-to-end.
- Re-running local migrations is idempotent and reports no duplicate applies.
- Central Flyway migrate/validate behavior remains unchanged.
- `scripts/init-db.sh all` succeeds with both paths active.

## Rollback Strategy

If local console migration runner introduces regressions:

1. Restore previous `scripts/` behavior from version control.
2. Re-enable prior local Flyway path temporarily.
3. Restore local data from snapshot before rerunning migrations.
4. Reattempt console runner rollout after root-cause fix.
