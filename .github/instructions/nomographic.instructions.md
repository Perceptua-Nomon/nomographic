---
applyTo: "**"
---

# nomographic Coding Instructions

nomographic manages ArcadeDB schemas and migrations for the nomon robot fleet. It has two independent database targets with separate migration sets.

## Database Targets

| Target | Directory | Purpose | Deployment |
|--------|-----------|---------|-----------|
| **Central** | `central/sql/` | Fleet-wide data: vehicle registry, telemetry, users, tokens | Dedicated ArcadeDB server |
| **Local** | `local/sql/` | On-device operational state and local intelligence | Embedded ArcadeDB per nomon |

Central and local schemas are **fully independent**. Version sequences do not cross-reference. A `V1` in `central/` and a `V1` in `local/` are unrelated.

## Migration File Naming

```
V{version}__{description}.sql
```

Examples:
- `central/sql/V1__create_vehicle_schema.sql`
- `central/sql/V2__add_user_schema.sql`
- `central/sql/V3__create_refresh_token.sql`
- `local/sql/V1__create_device_schema.sql`

Rules:
- Version numbers are sequential integers starting at 1, separately for central and local.
- Descriptions use lowercase with underscores (`create_vehicle_schema`, not `CreateVehicleSchema`).
- Double underscore (`__`) separates version number from description.
- Never reuse or skip version numbers.

## ArcadeDB DDL Patterns

```sql
-- Vertex types: PascalCase names
CREATE VERTEX TYPE Vehicle IF NOT EXISTS;
CREATE PROPERTY Vehicle.vin IF NOT EXISTS STRING;
ALTER PROPERTY Vehicle.vin MANDATORY true;
ALTER PROPERTY Vehicle.vin NOTNULL true;
CREATE PROPERTY Vehicle.registered_at IF NOT EXISTS DATETIME;
ALTER PROPERTY Vehicle.registered_at MANDATORY true;

-- Unique indexes
CREATE INDEX IF NOT EXISTS ON Vehicle (vin) UNIQUE;

-- Edge types: PascalCase names, past-tense or Has-prefix
CREATE EDGE TYPE HasTelemetry IF NOT EXISTS;
CREATE PROPERTY HasTelemetry.recorded_at IF NOT EXISTS DATETIME;

-- Document types (non-graph records)
CREATE DOCUMENT TYPE RefreshToken IF NOT EXISTS;
CREATE PROPERTY RefreshToken.token IF NOT EXISTS STRING;
CREATE PROPERTY RefreshToken.expires_at IF NOT EXISTS DATETIME;
```

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Vertex type | PascalCase | `Vehicle`, `TelemetryReading` |
| Edge type | PascalCase | `HasTelemetry`, `OwnedBy` |
| Document type | PascalCase | `RefreshToken` |
| Property | snake_case | `registered_at`, `firmware_version` |
| Index | auto (ON Type(prop)) | `ON Vehicle (vin)` |

## Migration Immutability Rules

1. **Never modify a migration that has already been applied.** Create a new versioned file instead.
2. Every migration file handles **exactly one logical change** (one schema concept or one relationship).
3. All `CREATE` statements use `IF NOT EXISTS` for idempotency — the migration runner may replay a migration on failure.
4. Use `ALTER PROPERTY` for `MANDATORY` and `NOTNULL` constraints — these must follow the `CREATE PROPERTY`.

## Validation & Testing

```bash
# Validate central migrations (dry-run)
cd nomographic && ./scripts/migrate-central.sh validate

# Validate local migrations (dry-run)
cd nomographic && ./scripts/migrate-local.sh validate

# Full deploy to local dev instance
cd nomographic && ./scripts/migrate-central.sh
```

- Always run `validate` before committing new migration files.
- The migration runner tracks applied versions; do not rename or reorder existing files.

## Security

- No hardcoded credentials, connection strings, or passwords in migration SQL files.
- Connection configuration belongs in `.env` (see `.env.example`) — never in source.
- Avoid `DROP` statements in migrations unless absolutely required; prefer additive changes.

## Project Structure

```
central/sql/      Versioned central server migrations (V1, V2, V3...)
local/sql/        Versioned local device migrations (V1...)
scripts/          migrate-central.sh, migrate-local.sh, init-db.sh, seed-central.sh
docs/             architecture.md, roadmap.md, adr/
docker-compose.yml  Local dev ArcadeDB instance
systemd/          Service unit files for production deployment
```

## Key Workflows

### Adding a new vertex type to central
1. Create `central/sql/V{N+1}__add_{type_name}_schema.sql`
2. Define vertex type, properties, constraints, indexes using the DDL patterns above
3. Run `./scripts/migrate-central.sh validate`
4. Commit the new file

### Adding a property to an existing type
1. Create `central/sql/V{N+1}__add_{property}_{type}.sql`
2. Use `CREATE PROPERTY TypeName.new_prop IF NOT EXISTS STRING;`
3. Optionally `ALTER PROPERTY TypeName.new_prop MANDATORY true;`
4. Validate and commit
