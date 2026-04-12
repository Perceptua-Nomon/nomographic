# nomographic

Database schemas and migration tooling for the nomon fleet.

## Overview

nomographic manages [ArcadeDB](https://arcadedb.com/) schemas for two targets:

| Instance | Database | Runtime | SQL Directory |
|----------|----------|---------|---------------|
| Central | `nomon_central` | Persistent ArcadeDB server (Docker Compose) | `central/sql/` |
| Local | `nomon_local` | Embedded filesystem DB (temporary Docker container) | `local/sql/` |

Both targets use custom ArcadeDB HTTP API runners for migration management. After each migration, a post-migration hook automatically creates `{Type}Meta` lineage vertices and `Supersedes` edges to track schema history.

## Structure

```
nomographic/
├── central/
│   └── sql/                   # Central versioned migrations (V1__, V2__, ...)
├── local/
│   └── sql/                   # Local versioned migrations (independent version series)
├── scripts/
│   ├── init-db.sh             # Full orchestrator: spin up, create DBs, migrate, seed
│   ├── migrate-central.sh     # Central migration runner
│   ├── migrate-local.sh       # Local migration runner
│   ├── lib/
│   │   └── migrate-common.sh  # Shared lineage tracking library
│   ├── deploy-local.sh        # Deploy local migrations to Pi or local machine
│   └── seed-central.sh        # Seed central with test records
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

1. Use `IF NOT EXISTS` on all `CREATE` statements.
2. Keep each migration to one logical change.
3. Never edit an already-applied migration — add a new version instead.
4. Type names are PascalCase, property names are snake_case.
5. Central and local version series are independent.

## Quick Start

```bash
# 1) Copy and configure environment
cp .env.example .env
# Edit .env — set ARCADEDB_ROOT_PASSWORD

# 2) Start central ArcadeDB server
docker compose up -d

# 3) Initialize both targets (creates DBs, applies all migrations, runs lineage hook)
./scripts/init-db.sh

# 4) Optional: seed central with test data
./scripts/seed-central.sh
```

## Script Reference

| Script | Subcommands | Purpose |
|--------|-------------|---------|
| `scripts/init-db.sh` | — | Orchestrate full setup: start check, create DBs, migrate, seed |
| `scripts/migrate-central.sh` | `migrate` `validate` `info` `reconcile-lineage` | Central migration runner |
| `scripts/migrate-local.sh` | `migrate` `validate` `info` `reconcile-lineage` | Local migration runner |
| `scripts/deploy-local.sh` | `[pi-host]` | Sync and apply local migrations on Pi or local machine |
| `scripts/seed-central.sh` | — | Seed central test records |

## Central Workflow

```bash
# Apply pending migrations (also runs lineage hook per migration)
./scripts/migrate-central.sh migrate

# Validate checksums against SchemaMigration records
./scripts/migrate-central.sh validate

# Show applied/pending status
./scripts/migrate-central.sh info

# Re-run lineage hook for all applied migrations (safe to run repeatedly)
./scripts/migrate-central.sh reconcile-lineage
```

## Local Workflow

```bash
# Apply local migrations
./scripts/migrate-local.sh migrate

# Validate checksums
./scripts/migrate-local.sh validate

# Show status
./scripts/migrate-local.sh info

# Reconcile lineage
./scripts/migrate-local.sh reconcile-lineage
```

## Schema Lineage Tracking

After every migration is applied, `scripts/lib/migrate-common.sh` automatically:

1. Parses the SQL file to detect affected types (created / modified / deleted).
2. Creates a `{Type}Meta` vertex type if it doesn't exist.
3. Inserts a new `{Type}Meta` record capturing `type_name`, `migration_file`, `change_type`, and `applied_at`.
4. If a previous meta record exists for the type, creates a `Supersedes` edge from the old record to the new one, forming a chronological linked list.

This produces a queryable lineage graph:

```sql
-- All lineage records for Vehicle
SELECT * FROM VehicleMeta ORDER BY applied_at;

-- Follow the history chain from the earliest record
MATCH {type: VehicleMeta, as: v} -Supersedes-> {as: next} RETURN v, next;
```

The `reconcile-lineage` subcommand re-runs the hook for all already-applied migrations, relying on per-type idempotency to skip existing records. Use it to recover from a migration that succeeded but whose lineage hook was interrupted.

## Environment

Copy example config:

```bash
cp .env.example .env
```

Key variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `ARCADEDB_ROOT_PASSWORD` | `changeme_before_deploy` | Central root password — **change before any non-local use** |
| `ARCADEDB_HOST` | `localhost` | Central server host |
| `ARCADEDB_HTTP_PORT` | `2480` | Central HTTP API port |
| `ARCADEDB_LOCAL_DATA` | `local/data` | Local embedded DB directory |
| `ARCADEDB_LOCAL_DB` | `nomon_local` | Local DB name |
| `LOCAL_MIGRATOR_IMAGE` | `arcadedata/arcadedb:latest` | Docker image for local migration runner |
| `LOCAL_MIGRATOR_HTTP_PORT` | `2481` | Temporary local migrator API port |

## Further Reading

- `docs/architecture.md` — schema inventory, migration strategy, lineage tracking design
- `docs/roadmap.md` — completed and planned phases
- `docs/adr/002-complete-flyway-removal.md` — rationale for ArcadeDB-native migrations
