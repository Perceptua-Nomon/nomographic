# nomographic

Database schemas and Flyway migrations for the nomon fleet.

## Overview

nomographic manages [ArcadeDB](https://arcadedb.com/) schemas for the nomon robot project. ArcadeDB is a multi-model database supporting document, graph, key-value, and time-series models. We primarily use its **document + graph** capabilities.

Two independent database instances are managed from this repo:

| Instance | Path | ArcadeDB Mode | Purpose |
|----------|------|---------------|---------|
| **Central** | `central/` | Server | Fleet-wide vehicle registry, telemetry history, user data, cross-device analytics |
| **Local** | `local/` | Embedded | On-device operational state and local intelligence (deployed to each nomon) |

## Structure

```
nomographic/
├── central/
│   ├── flyway.toml          # Flyway config for the central server instance
│   └── sql/                  # Versioned migration scripts
│       ├── V1__create_vehicle_schema.sql
│       ├── V2__add_user_schema.sql
│       └── V3__create_refresh_token.sql
├── local/
│   ├── flyway.toml          # Flyway config for the local embedded instance
│   └── sql/                  # Versioned migration scripts
│       ├── V1__create_device_schema.sql
│       └── ...
├── docker-compose.yml        # ArcadeDB with Gremlin Server plugin
├── scripts/
│   ├── init-db.sh            # Create databases and run all migrations
│   ├── migrate.sh            # Run Flyway commands against a database
│   └── seed.sh               # Insert test data
├── docs/
│   ├── architecture.md       # Schema design, query language strategy
│   └── roadmap.md            # Migration version status
└── README.md
```

## Migration Conventions

Migrations follow [Flyway naming conventions](https://documentation.red-gate.com/fd/migrations-184127470.html):

```
V{version}__{description}.sql
```

- **Version:** Sequential integer (`V1`, `V2`, `V3`, …). Central and local version numbers are independent.
- **Description:** Snake_case summary of the change (e.g., `create_vehicle_schema`, `add_telemetry_edges`).
- **Separator:** Double underscore (`__`) between version and description.

### Rules

1. Use `IF NOT EXISTS` on all `CREATE` statements for idempotency.
2. Each migration file handles exactly **one logical change**.
3. **Never modify** a migration that has already been applied — create a new versioned file.
4. Vertex and edge type names are **PascalCase**. Property names are **snake_case**.
5. Central and local schemas evolve independently.

## Commands

```bash
# Validate migrations (check pending/applied consistency)
flyway -configFiles=central/flyway.toml validate
flyway -configFiles=local/flyway.toml validate

# Apply pending migrations
flyway -configFiles=central/flyway.toml migrate
flyway -configFiles=local/flyway.toml migrate

# Show migration status
flyway -configFiles=central/flyway.toml info
flyway -configFiles=local/flyway.toml info
```

## ArcadeDB SQL Notes

ArcadeDB uses an extended SQL dialect. Key patterns used in this repo:

```sql
-- Vertex types (like tables, but graph-aware)
CREATE VERTEX TYPE Vehicle IF NOT EXISTS;

-- Properties
ALTER TYPE Vehicle IF NOT EXISTS CREATE PROPERTY vin STRING;

-- Edge types (relationships between vertices)
CREATE EDGE TYPE HasTelemetry IF NOT EXISTS;

-- Indexes
CREATE INDEX IF NOT EXISTS ON Vehicle (vin) UNIQUE;
```

Application-layer queries (when nomothetic connects to ArcadeDB) should use
**Gremlin** (Apache TinkerPop) rather than ArcadeDB SQL. This enables future
migration to hosted graph databases (e.g. AWS Neptune) without rewriting
queries. See [docs/architecture.md](docs/architecture.md) for the full
query language strategy.

## Quick Start

The fastest way to get both databases running:

```bash
# 1. Start ArcadeDB via Docker Compose
docker compose up -d

# 2. Create databases and run all migrations
./scripts/init-db.sh

# 3. (Optional) Seed with test data
./scripts/seed.sh
```

This creates both `nomon_central` (fleet server) and `nomon_local` (embedded device) databases with all migrations applied.

### Script Reference

| Script | Purpose |
|--------|---------|
| `scripts/init-db.sh [central\|local\|all]` | Create databases and run migrations |
| `scripts/migrate.sh <central\|local> [migrate\|validate\|info]` | Run Flyway commands against a database |
| `scripts/seed.sh` | Insert test user, vehicle, and ownership edge |

### Environment

Copy `.env.example` to `.env` and adjust as needed:

```bash
cp .env.example .env
```

See `.env.example` for all available configuration variables and their defaults.

---

## Manual Setup

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (for the central ArcadeDB server instance)
- [Flyway CLI](https://documentation.red-gate.com/fd/command-line-184127404.html) (for running migrations)
- Java 11+ (required by Flyway)

### Central Instance (Docker)

Start an ArcadeDB server for fleet-wide testing:

```bash
docker run -d \
  --name nomon-arcadedb-central \
  -p 2480:2480 \
  -p 2424:2424 \
  -e JAVA_OPTS="-Darcadedb.server.rootPassword=testpassword" \
  arcadedata/arcadedb:latest
```

| Port | Protocol | Purpose |
|------|----------|---------|
| 2480 | HTTP | REST API and Studio web UI (`http://localhost:2480`) |
| 2424 | Binary | Native binary protocol (used by JDBC driver) |

Create the `nomon_central` database via the HTTP API:

```bash
curl -u root:testpassword \
  -X POST "http://localhost:2480/api/v1/server" \
  -d '{"command": "create database nomon_central"}'
```

Run Flyway migrations against the central instance:

```bash
cd nomographic
flyway -configFiles=central/flyway.toml \
  -url="jdbc:arcadedb:remote:localhost/nomon_central" \
  -user=root \
  -password=testpassword \
  migrate
```

Validate migration state:

```bash
flyway -configFiles=central/flyway.toml \
  -url="jdbc:arcadedb:remote:localhost/nomon_central" \
  -user=root \
  -password=testpassword \
  validate
```

### Local Instance (Embedded)

ArcadeDB embedded mode stores data directly on the filesystem — no server
process needed. This is how each nomon Pi runs its local database.

For local testing, Flyway opens the embedded database from a local directory:

```bash
cd nomographic

# Create the data directory
mkdir -p local/data

# Run migrations (creates nomon_local database in local/data/)
flyway -configFiles=local/flyway.toml migrate

# Validate
flyway -configFiles=local/flyway.toml validate
```

The embedded database path is configured in `local/flyway.toml`:
```
url = "jdbc:arcadedb:local/data/nomon_local"
```

### Docker Compose (Optional)

The repo includes a [`docker-compose.yml`](docker-compose.yml) that configures
an ArcadeDB server with health checks and the Gremlin Server plugin enabled.
See [`.env.example`](.env.example) for configurable variables.

```bash
# Start
docker compose up -d

# Stop (preserves data volume)
docker compose down

# Stop and remove data
docker compose down -v
```

### Environment Variables

Set these when connecting nomothetic or Flyway to a non-default instance:

| Variable | Default | Description |
|----------|---------|-------------|
| `ARCADEDB_HOST` | `localhost` | ArcadeDB server hostname |
| `ARCADEDB_HTTP_PORT` | `2480` | HTTP API port |
| `ARCADEDB_BINARY_PORT` | `2424` | Binary protocol port (JDBC) |
| `ARCADEDB_ROOT_PASSWORD` | `testpassword` | Root password for ArcadeDB server |
| `ARCADEDB_LOCAL_DATA` | `local/data` | Local embedded database directory |

For Flyway, credentials can also be placed in a gitignored secret file:

```bash
# flyway-central.secret.toml (gitignored)
[environments.default]
user = "root"
password = "your-password-here"
```

### Current Integration Status

> nomothetic connects to ArcadeDB via the HTTP/Gremlin API using
> `DatabaseClient` (`db.py`) with pluggable store backends:
> - **`GremlinUserStore`** — user vertices (central mode)
> - **`GremlinFleetStore`** — vehicle vertices and `OwnsDevice` edges (central mode)
> - **`GremlinTokenStore`** — refresh token vertices (central mode)
>
> In device mode, **in-memory stores** are used (single-owner, no database).
>
> ArcadeDB connection requires a running instance (via Docker Compose) with
> the Gremlin Server plugin enabled. See `docker-compose.yml` and
> `.env.example` for configuration.
