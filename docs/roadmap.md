# nomographic — Development Roadmap

## Status Summary

### Central Database

| Version | Name | Status |
|---------|------|--------|
| V1 | Vehicle & Telemetry Schema | ✅ Complete |
| V2 | User & Device Ownership Schema | ✅ Complete |

### Local Database

| Version | Name | Status |
|---------|------|--------|
| V1 | Device State Schema | ✅ Complete |

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
- ✅ `flyway -configFiles=central/flyway.toml validate` passes
- ✅ `flyway -configFiles=central/flyway.toml migrate` applies cleanly
- ✅ `User` vertex type queryable with email lookup
- ✅ `OwnsDevice` edge traversable from User to Vehicle

---

## Future Considerations

- **V3 Central — Refresh Token Storage:** Dedicated `RefreshToken` vertex
  type if multi-device session management is needed (single-token-per-user
  may suffice initially).

---

## Phase 1 — Deployment Automation

Tooling to make the databases runnable with a single command.

- [x] `docker-compose.yml` — ArcadeDB service with health check and Gremlin plugin
- [x] `scripts/migrate.sh` — Flyway wrapper with env-var-driven JDBC URLs
- [x] `scripts/init-db.sh` — Database creation and migration runner with health-check wait loop
- [x] `scripts/seed.sh` — Idempotent test data seeding (user, vehicle, ownership edge)
- [x] `.env.example` — Documented environment variable defaults
- [x] `.gitignore` — Ignores `.env`, data directories, secret configs
- [x] README Quick Start section — single-command setup instructions
- [x] Architecture doc — Deployment Automation section describing scripts and Docker Compose
- **V2 Local — AI Context:** On-device intelligence data (learned patterns,
  environment models) if local AI features are added.
- **Telemetry partitioning:** Time-based pruning of `TelemetryReading`
  vertices for long-running deployments.
