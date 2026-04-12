# nomographic — Architecture

## Overview

nomographic manages the ArcadeDB graph database schemas for the nomon fleet.
Two independent database instances serve different roles:

```
┌─────────────────────────────────────────────────────┐
│                 Central Server                       │
│                                                      │
│  nomothetic (central mode)                           │
│       │  HTTP API (jdbc:arcadedb:remote:…)           │
│       ▼                                              │
│  ArcadeDB Server ── nomon_central                    │
│       │                                              │
│  ┌────┴──────────────────────────────────────┐       │
│  │  User ──OwnsDevice──▶ Vehicle             │       │
│  │                         │                 │       │
│  │                    HasTelemetry            │       │
│  │                         │                 │       │
│  │                         ▼                 │       │
│  │                  TelemetryReading          │       │
│  └───────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│             Each nomon Device (Pi)                    │
│                                                      │
│  nomothetic (device mode)                            │
│       │  Embedded (jdbc:arcadedb:local/…)            │
│       ▼                                              │
│  ArcadeDB Embedded ── nomon_local                    │
│       │                                              │
│  ┌────┴──────────────────────────────────────┐       │
│  │  DeviceState ──Performed──▶ OperationLog  │       │
│  └───────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────┘
```

## Database Instances

### Central (`central/`)

Runs as an ArcadeDB server instance on dedicated infrastructure. Stores
fleet-wide data that spans multiple devices and users.

**Access:** nomothetic (central mode) connects via ArcadeDB's HTTP API.
Credentials are provided through the `ARCADEDB_ROOT_PASSWORD` environment variable.

**Use cases:**
- User registration and authentication (password hashes, profiles)
- Device ownership and access control (which user owns which device)
- Telemetry history aggregation (time-series from all devices)
- Fleet analytics and cross-device queries

### Local (`local/`)

Runs as an embedded ArcadeDB instance on each Raspberry Pi. Stores
operational state local to one device. No network connectivity required.

**Access:** nomothetic (device mode) opens the embedded database directly
from the filesystem.

**Use cases:**
- Current device state (boot count, firmware version, status)
- Operation log for on-device diagnostics and local intelligence
- Survives network outages — device operates fully offline

## Schema Design

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Vertex types | PascalCase | `Vehicle`, `User`, `TelemetryReading` |
| Edge types | PascalCase | `HasTelemetry`, `OwnsDevice`, `Performed` |
| Properties | snake_case | `battery_voltage`, `created_at`, `device_id` |
| Indexes | Auto-named by ArcadeDB | `CREATE INDEX IF NOT EXISTS ON Type (prop)` |

### Central Schema (current: V3)

| Type | Kind | Properties | Indexes |
|------|------|-----------|--------|
| `Vehicle` | Vertex | `vin`, `model`, `firmware_version`, `registered_at`, `last_seen_at` | `vin` UNIQUE |
| `TelemetryReading` | Vertex | `battery_voltage`, `cpu_temp_c`, `uptime_seconds`, `recorded_at` | `recorded_at` NOTUNIQUE |
| `HasTelemetry` | Edge | `recorded_at` | — |
| `User` | Vertex | `email`, `display_name`, `password_hash`, `created_at`, `last_login_at`, `active` | `email` UNIQUE |
| `OwnsDevice` | Edge | `registered_at`, `role` | — |
| `RefreshToken` | Vertex | `token_hash`, `email`, `created_at`, `expires_at` | `token_hash` UNIQUE, `email` NOTUNIQUE, `expires_at` NOTUNIQUE |

### Local Schema (current: V1)

| Type | Kind | Properties | Indexes |
|------|------|-----------|---------|
| `DeviceState` | Vertex | `device_id`, `firmware_version`, `boot_count`, `last_boot_at`, `status` | `device_id` UNIQUE |
| `OperationLog` | Vertex | `operation`, `result`, `detail`, `occurred_at` | `occurred_at` NOTUNIQUE |
| `Performed` | Edge | `occurred_at` | — |

## Migration Strategy

Migrations use a unified strategy:

- Central: ArcadeDB API runner (`scripts/migrate.sh`) over `central/sql/V*__*.sql`
- Local: ArcadeDB API runner (`scripts/migrate-local.sh`) over `local/sql/V*__*.sql`

**Key rules:**
1. `IF NOT EXISTS` on all `CREATE` statements (idempotent)
2. One logical change per migration file
3. Never modify applied migrations — always create new versions
4. Central and local version numbers are independent
5. Credentials never appear in migration files or committed configs

**Migration configs:**
- Central runner metadata stored in `SchemaMigration` vertex records in `nomon_central`
- Local runner metadata stored in `SchemaMigration` vertex records in `nomon_local`

## Query Language Strategy

**DDL (migrations):** ArcadeDB-native SQL. Schema definition is inherently
engine-specific — there is no portable DDL standard for graph databases.
Both central and local ArcadeDB API runners execute ArcadeDB SQL migrations.

**DML (application queries):** Use **Apache TinkerPop Gremlin** for all
application-layer graph queries. Gremlin is the most widely supported
graph traversal language:

- ArcadeDB: native Gremlin support
- AWS Neptune: Gremlin is a primary query language
- JanusGraph, Azure Cosmos DB (Gremlin API): also supported

This enables a future migration from ArcadeDB to a hosted graph database
(e.g. Neptune) without rewriting application queries. Only the DDL
migrations and connection configuration would need to change.

### ArcadeDB SQL Patterns (DDL only)

```sql
-- Vertex type creation
CREATE VERTEX TYPE TypeName IF NOT EXISTS;
CREATE PROPERTY TypeName.prop_name IF NOT EXISTS TYPE;

-- Edge type creation
CREATE EDGE TYPE EdgeName IF NOT EXISTS;

-- Index creation
CREATE INDEX IF NOT EXISTS ON TypeName (prop) UNIQUE;
CREATE INDEX IF NOT EXISTS ON TypeName (prop) NOTUNIQUE;
```

### Gremlin Patterns (application queries)

```groovy
// Insert vertex
g.addV('User').property('email', 'user@example.com').property('display_name', 'Alice')

// Create edge
g.V().has('User', 'email', 'user@example.com').addE('OwnsDevice').to(V().has('Vehicle', 'vin', 'NM-001'))

// Traverse: find devices owned by a user
g.V().has('User', 'email', 'user@example.com').out('OwnsDevice').valueMap()

// Traverse: find telemetry for a device
g.V().has('Vehicle', 'vin', 'NM-001').out('HasTelemetry').order().by('recorded_at', desc).limit(10).valueMap()
```

## Security

- Database credentials are never committed to source
- Central mode: credentials via `ARCADEDB_ROOT_PASSWORD` env var
- Local mode: embedded, no credentials by default
- Password hashes in the `User` vertex are bcrypt hashes — never stored in
  plaintext
- The application layer (nomothetic) handles all access control; the database
  does not enforce row-level security

## Deployment Automation

### Docker Compose

`docker-compose.yml` provides a single-command ArcadeDB server for
development and testing. Key features:

- ArcadeDB with Gremlin Server plugin enabled (via `JAVA_OPTS`)
- Health check on `/api/v1/ready` (used by `init-db.sh` to wait for readiness)
- Persistent volume for database files
- Configurable ports via `ARCADEDB_HTTP_PORT` and `ARCADEDB_BINARY_PORT`
- Root password via `ARCADEDB_ROOT_PASSWORD` environment variable

### Scripts

Four shell scripts in `scripts/` automate database lifecycle tasks:

| Script | Purpose |
|--------|---------|
| `init-db.sh` | Waits for ArcadeDB health and initializes selected targets. Central and local both use ArcadeDB API runners. Accepts `central`, `local`, or `all` (default). |
| `migrate.sh` | Central migration runner. Applies `migrate`, `validate`, or `info` for `nomon_central` via ArcadeDB HTTP API. |
| `migrate-local.sh` | Local migration runner. Applies local SQL scripts in version order and tracks state/checksums in `SchemaMigration`. |
| `seed.sh` | Inserts test data (user, vehicle, ownership edge) into `nomon_central` via HTTP API. Idempotent — checks for existing records before inserting. |

All scripts use `set -euo pipefail`, read configuration from environment
variables with sensible defaults, and include `--help`-style usage text.

### Typical Workflow

```bash
# Start ArcadeDB
docker compose up -d

# Initialize databases and apply migrations
./scripts/init-db.sh

# Seed test data
./scripts/seed.sh

# Check migration status
./scripts/migrate.sh info
./scripts/migrate-local.sh info

# Tear down (preserves data volume)
docker compose down
```
