# ADR-002: Complete Flyway Removal — Unified ArcadeDB API Runners

## Status
Accepted

## Date
2026-04-12

## Supersedes
[ADR-001](001-local-console-migrations.md)

## Context

ADR-001 introduced a split migration strategy: Flyway for the central server
database and an ArcadeDB HTTP API runner for the local embedded database.
While this reduced local deployment dependencies, it left the project with
two different migration engines and retained Flyway as a central dependency.

Flyway introduced operational friction:
- Required either the Flyway CLI or a Docker fallback image for central
  migrations.
- Added Flyway-specific configuration files (`flyway.toml`) and environment
  variables (`ARCADEDB_USER`, `ARCADEDB_PASSWORD`, `FLYWAY_DOCKER_IMAGE`).
- Created a dependency on Flyway's JDBC ArcadeDB driver, which has
  compatibility constraints.

Meanwhile, the local ArcadeDB API runner (`scripts/migrate-local.sh`) proved
reliable and self-contained, handling migration ordering, checksum tracking,
and idempotency without external tooling.

## Decision

Remove all Flyway dependencies and unify both central and local migration
targets on ArcadeDB HTTP API runners.

- `scripts/migrate.sh` is rewritten as an ArcadeDB HTTP API runner for
  central migrations, matching the pattern established by
  `scripts/migrate-local.sh`.
- Both runners track state via `SchemaMigration` vertex records with
  `version`, `description`, `script`, `checksum`, and `applied_at` fields.
- All Flyway configuration files (`flyway.toml`), Flyway-specific environment
  variables, and Flyway Docker image references are removed.

## Rationale

- **Eliminates external dependency.** No Flyway CLI or Docker image needed
  for any migration workflow.
- **Consistent tooling.** Both targets use the same migration engine pattern,
  reducing cognitive load and maintenance surface.
- **Proven pattern.** The local API runner has been validated in production use
  since Phase 2.
- **Simpler configuration.** Only `ARCADEDB_ROOT_PASSWORD` is needed for
  central authentication (via the ArcadeDB HTTP API), replacing three
  separate Flyway-specific variables.

## Consequences

Positive:
- Zero external migration tool dependencies.
- Unified migration UX: `./scripts/migrate.sh [migrate|validate|info]` for
  central, `./scripts/migrate-local.sh [migrate|validate|info]` for local.
- Reduced `.env.example` surface — fewer variables to configure.
- All migration state is stored in ArcadeDB itself (`SchemaMigration` vertex
  type), not in external Flyway metadata tables.

Trade-offs:
- nomographic fully owns migration ordering, state tracking, checksum
  validation, and idempotency for both targets.
- Any Flyway-specific features (baseline, undo, callbacks) are not available.
  These were not used by the project.

## Implementation Notes

- `scripts/migrate.sh` connects to the already-running ArcadeDB server (no
  container management) and executes `central/sql/V*__*.sql` in version
  order.
- `scripts/init-db.sh` updated to call `migrate.sh` without the `central`
  positional argument.
- Both `central/flyway.toml` and `local/flyway.toml` deleted.
- Flyway-specific entries removed from `.env.example` and `.gitignore`.
- All Flyway references removed from documentation across nomographic,
  nomothetic, and nomourgoi repositories.

## Verification Requirements

- `./scripts/migrate.sh migrate` applies central migrations successfully.
- `./scripts/migrate.sh validate` passes with matching checksums.
- `./scripts/init-db.sh all` succeeds on clean and already-migrated states.
- `grep -ri flyway` across the workspace returns zero matches.
