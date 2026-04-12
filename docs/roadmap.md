# nomographic — Development Roadmap

## Status Summary

### Central Database

| Version | Name | Status |
|---------|------|--------|
| V1 | Vehicle & Telemetry Schema | ✅ Complete |
| V2 | User & Device Ownership Schema | ✅ Complete |
| V3 | Refresh Token Storage | ✅ Complete |

### Local Database

| Version | Name | Status |
|---------|------|--------|
| V1 | Device State Schema | ✅ Complete |

### Tooling

| Phase | Name | Status |
|-------|------|--------|
| 1 | Deployment Automation | ✅ Complete |
| 2 | Local Migrations Without Flyway | ✅ Complete |
| 3 | Complete Flyway Removal | ✅ Complete |
| 4 | Schema Lineage Tracking via MetaTypes | ✅ Complete |

---

## Completed

### V1 — Central: Vehicle & Telemetry Schema

**File:** `central/sql/V1__create_vehicle_schema.sql`

**Deliverables:**
- [x] `Vehicle` vertex type: `vin`, `model`, `firmware_version`, `registered_at`, `last_seen_at`
- [x] `TelemetryReading` vertex type: `battery_voltage`, `cpu_temp_c`, `uptime_seconds`, `recorded_at`
- [x] `HasTelemetry` edge type: links Vehicle → TelemetryReading
- [x] Unique index on `Vehicle.vin`
- [x] Non-unique index on `TelemetryReading.recorded_at`

### V1 — Local: Device State Schema

**File:** `local/sql/V1__create_device_schema.sql`

**Deliverables:**
- [x] `DeviceState` vertex type: `device_id`, `firmware_version`, `boot_count`, `last_boot_at`, `status`
- [x] `OperationLog` vertex type: `operation`, `result`, `detail`, `occurred_at`
- [x] `Performed` edge type: links DeviceState → OperationLog
- [x] Unique index on `DeviceState.device_id`
- [x] Non-unique index on `OperationLog.occurred_at`

---

### V2 — Central: User & Device Ownership Schema

**File:** `central/sql/V2__add_user_schema.sql`

**Deliverables:**
- [x] `User` vertex type:
  - `email` (STRING) — login identifier
  - `display_name` (STRING) — user-visible name
  - `password_hash` (STRING) — bcrypt hash, never plaintext
  - `created_at` (DATETIME) — registration timestamp
  - `last_login_at` (DATETIME) — most recent successful login
  - `active` (BOOLEAN) — soft-delete / account disable flag
- [x] Unique index on `User.email`
- [x] `OwnsDevice` edge type (User → Vehicle):
  - `registered_at` (DATETIME) — when ownership was established
  - `role` (STRING) — access level: `owner`, `operator`, `viewer`

**Graph relationships:**
```
User ──OwnsDevice──▶ Vehicle ──HasTelemetry──▶ TelemetryReading
```

**Exit criteria:**
- ✅ `./scripts/migrate-central.sh validate` passes
- ✅ `./scripts/migrate-central.sh migrate` applies cleanly
- ✅ `User` vertex type queryable with email lookup
- ✅ `OwnsDevice` edge traversable from User to Vehicle

---

## Phase 1 — Deployment Automation

Tooling to make the databases runnable with a single command.

- [x] `docker-compose.yml` — ArcadeDB service with health check and Gremlin plugin
- [x] `scripts/migrate-central.sh` — Flyway wrapper with env-var-driven JDBC URLs
- [x] `scripts/init-db.sh` — Database creation and migration runner with health-check wait loop
- [x] `scripts/seed-central.sh` — Idempotent test data seeding (user, vehicle, ownership edge)
- [x] `.env.example` — Documented environment variable defaults
- [x] `.gitignore` — Ignores `.env`, data directories, secret configs
- [x] README Quick Start section — single-command setup instructions
- [x] Architecture doc — Deployment Automation section describing scripts and Docker Compose

---

## Phase 2 — Local Migrations Without Flyway (Implemented)

Goal: keep nomographic self-contained by removing Flyway from the local
embedded workflow and using ArcadeDB console-driven migrations for local
schema evolution, while preserving Flyway for central server migrations.

### 2.1 — Local migration runner and script split

- [x] Add local migration runner script (ArcadeDB console/API based) to apply
  `local/sql/V*__*.sql` in version order and persist applied versions in
  local database metadata.
- [x] Refactor `scripts/migrate-central.sh` to central-only Flyway path.
- [x] Route local workflows to `scripts/migrate-local.sh`.
- [x] Update `scripts/init-db.sh` so `local` target uses the console runner.

### 2.2 — Dependency and compose updates

- [x] Update `.env.example` migration variables so local workflow does not
  require Flyway-specific settings.
- [x] Add/adjust Docker helper configuration so the ArcadeDB console/API path can run
  reproducibly in CI/dev even when host tools are missing.
- [x] Keep central Flyway config intact (`central/flyway.toml`).

### 2.3 — Documentation and ADR

- [x] Add ADR documenting migration strategy split:
  `docs/adr/001-local-console-migrations.md`
  - central = Flyway
  - local = ArcadeDB console runner
- [x] Update README commands and quick-start flow to remove local Flyway
  examples and replace with local console migration commands.
- [x] Update `docs/architecture.md` migration strategy and script reference to
  reflect the split model.

### 2.4 — Validation and rollback

- [x] Add verification steps for central and local migration paths:
  - central: Flyway `validate` and `migrate`
  - local: runner `validate/info` and idempotent rerun
- [x] Document rollback playbook for local migration failures
  (restore local data snapshot, rerun from known version).

### Phase 2 Exit Criteria

- Local migration flow runs without Flyway installed.
- Central migration flow remains Flyway-based and unchanged.
- `./scripts/init-db.sh local` succeeds on clean and already-migrated states.
- README and architecture docs match actual script behavior.
- ADR accepted and linked from roadmap/architecture docs.

---

## Phase 3 — Complete Flyway Removal (Implemented)

Goal: unify both central and local migration targets on ArcadeDB HTTP API
runners, eliminating all Flyway dependencies from the project.

### Deliverables

- [x] Rewrite `scripts/migrate-central.sh` as ArcadeDB HTTP API runner for central
  migrations (matching local runner pattern)
- [x] Remove `central/flyway.toml` and `local/flyway.toml`
- [x] Remove Flyway-specific environment variables (`ARCADEDB_USER`,
  `ARCADEDB_PASSWORD`, `FLYWAY_DOCKER_IMAGE`) from `.env.example`
- [x] Remove Flyway runtime entries from `.gitignore`
- [x] Update `scripts/init-db.sh` to call `migrate-central.sh` without `central` arg
- [x] Update README, architecture docs, and roadmap
- [x] Create ADR-002 documenting the complete Flyway removal decision
- [x] Update ADR-001 status to superseded
- [x] Remove all Flyway references from nomourgoi agents, prompts, and context
- [x] Remove all Flyway references from nomothetic documentation

### Phase 3 Exit Criteria

- Zero Flyway references remain in the workspace.
- `./scripts/migrate-central.sh migrate` applies central migrations via ArcadeDB API.
- `./scripts/migrate-central.sh validate` validates central migration checksums.
- `./scripts/init-db.sh all` succeeds end-to-end.
- ADR-002 accepted and linked.

## Phase 4 — Schema Lineage Tracking via MetaTypes (Implemented)

Goal: automatically track which migrations touched which schema types,
forming a chronological linked list of changes per type via MetaType
vertices and Supersedes edges.

### Deliverables

- [x] Shared library `scripts/lib/migrate-common.sh` — extracted lineage
  logic consumed by both `migrate-central.sh` and `migrate-local.sh`
- [x] `parse_affected_types` — SQL parser extracting type names and change
  classifications (created / modified / deleted) from migration files
- [x] `record_lineage` — post-migration hook that creates `{Type}Meta`
  vertices and `Supersedes` edges after each migration is applied
- [x] `reconcile-lineage` subcommand added to both `migrate-central.sh` and
  `migrate-local.sh` — replays lineage for all previously applied
  migrations (idempotent)
- [x] `Supersedes` edge type: links previous MetaType head → new MetaType
  record, forming a chronological linked list per schema type
- [x] MetaType naming convention: `{Type}Meta` (e.g. `VehicleMeta`,
  `DeviceStateMeta`)
- [x] Lineage types are self-excluded from tracking (MetaType and
  Supersedes are filtered out by `parse_affected_types`)

### Phase 4 Exit Criteria

- `./scripts/migrate-central.sh migrate` records lineage automatically.
- `./scripts/migrate-local.sh migrate` records lineage automatically.
- `./scripts/migrate-central.sh reconcile-lineage` replays all central lineage.
- `./scripts/migrate-local.sh reconcile-lineage` replays all local lineage.
- MetaType records are idempotent — re-running does not duplicate records.
- `SchemaMigration`, `*Meta`, and `Supersedes` types are excluded from
  lineage tracking.

---

- **V2 Local — AI Context:** On-device intelligence data (learned patterns,
  environment models) if local AI features are added.
- **Telemetry partitioning:** Time-based pruning of `TelemetryReading`
  vertices for long-running deployments.
