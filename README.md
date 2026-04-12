# nomographic

Database schemas and migration tooling for the nomon fleet.

## Overview

nomographic manages [ArcadeDB](https://arcadedb.com/) schemas for two targets:

| Instance | Path | Runtime | Migration Engine |
|----------|------|---------|------------------|
| Central | `central/` | ArcadeDB server | ArcadeDB API runner (`scripts/migrate.sh`) |
| Local | `local/` | Embedded filesystem DB | ArcadeDB API runner (`scripts/migrate-local.sh`) |

Both targets use ArcadeDB HTTP API runners for self-contained migration management.

## Structure

```
nomographic/
├── central/
│   └── sql/
├── local/
│   └── sql/
├── scripts/
│   ├── init-db.sh
│   ├── migrate.sh
│   ├── migrate-local.sh
│   ├── deploy-local.sh
│   └── seed.sh
├── docs/
│   ├── architecture.md
│   ├── roadmap.md
│   └── adr/
└── docker-compose.yml
```

## Migration Conventions

Migration files use versioned naming:

```text
V{version}__{description}.sql
```

Rules:

1. Use `IF NOT EXISTS` on `CREATE` statements.
2. Keep each migration to one logical change.
3. Never edit an already-applied migration; add a new version instead.
4. Type names are PascalCase, property names are snake_case.
5. Central and local version series are independent.

## Quick Start

```bash
# 1) Start central ArcadeDB server
docker compose up -d

# 2) Initialize both targets
./scripts/init-db.sh

# 3) Optional test data for central
./scripts/seed.sh
```

## Script Reference

| Script | Purpose |
|--------|---------|
| `scripts/init-db.sh [central\|local\|all]` | Create/init DBs and run migrations for selected targets |
| `scripts/migrate.sh [migrate\|validate\|info]` | Central migration runner using ArcadeDB API and `SchemaMigration` metadata |
| `scripts/migrate-local.sh [migrate\|validate\|info]` | Local migration runner using ArcadeDB API and `SchemaMigration` metadata |
| `scripts/deploy-local.sh [pi-host]` | Sync and apply local migrations on Pi or local machine |
| `scripts/seed.sh` | Seed central test records |

## Central Workflow (ArcadeDB API Runner)

```bash
# apply
./scripts/migrate.sh migrate

# validate
./scripts/migrate.sh validate

# status
./scripts/migrate.sh info
```

Central runner behavior:

1. Connects to the already-running ArcadeDB server at `ARCADEDB_HOST:ARCADEDB_HTTP_PORT`.
2. Ensures `SchemaMigration` metadata type/index exists in `nomon_central`.
3. Applies `central/sql/V*__*.sql` in version order.
4. Records `version`, `description`, `script`, `checksum`, `applied_at` for idempotency.

## Local Workflow (ArcadeDB API Runner)

```bash
# apply local migrations in order from local/sql/
./scripts/migrate-local.sh migrate

# validate checksums against applied metadata
./scripts/migrate-local.sh validate

# status
./scripts/migrate-local.sh info
```

Local runner behavior:

1. Starts a temporary ArcadeDB container mounted to `ARCADEDB_LOCAL_DATA`.
2. Ensures local DB exists (default `nomon_local`).
3. Ensures `SchemaMigration` metadata type/index exists.
4. Applies `local/sql/V*__*.sql` in version order.
5. Records `version`, `script`, `checksum`, `applied_at` for idempotency.

## Environment

Copy example config:

```bash
cp .env.example .env
```

Key variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `ARCADEDB_HOST` | `localhost` | Central server host |
| `ARCADEDB_HTTP_PORT` | `2480` | Central HTTP API port |
| `ARCADEDB_BINARY_PORT` | `2424` | Central binary/JDBC port |
| `ARCADEDB_ROOT_PASSWORD` | `changeme_before_deploy` | Central root password |
| `ARCADEDB_LOCAL_DATA` | `local/data` | Local embedded DB directory |
| `ARCADEDB_LOCAL_DB` | `nomon_local` | Local DB name |
| `LOCAL_MIGRATOR_IMAGE` | `arcadedata/arcadedb:latest` | Image used by local migration runner |
| `LOCAL_MIGRATOR_HTTP_PORT` | `2481` | Temporary local migrator API port |
| `LOCAL_MIGRATOR_ROOT_PASSWORD` | `changeme_before_deploy` | Auth for temporary local migrator |

## Notes

- `docker-compose.yml` remains focused on central server runtime.
- See `docs/architecture.md` and `docs/adr/002-complete-flyway-removal.md` for design rationale.
