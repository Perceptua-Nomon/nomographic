# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Role

ArcadeDB schemas and ArcadeDB-native migration runners for two independent targets:

| Target | Database | Location |
|--------|----------|----------|
| Central | `nomon_central` | Docker Compose server — users, fleet, telemetry |
| Local | `nomon_local` | Pi-local ArcadeDB service — device operational state |

Central and local schema versions are independent — migration `V1` in `central/` and `V1` in `local/` are unrelated.

## Commands

```bash
# Central
docker compose up -d
./scripts/init-db.sh                        # full setup: create DBs + migrate
./scripts/migrate-central.sh migrate
./scripts/migrate-central.sh validate       # checksum validation
./scripts/migrate-central.sh info           # applied/pending status
./scripts/migrate-central.sh reconcile-lineage

# Local
./scripts/migrate-local.sh migrate
./scripts/migrate-local.sh validate
./scripts/migrate-local.sh info
./scripts/deploy-local.sh <pi-host>         # sync + migrate on Pi
```

## Migration Rules

1. Filename: `V{N}__{description}.sql` — increment `N` independently per `central/` and `local/`
2. All `CREATE` statements use `IF NOT EXISTS`
3. One logical change per migration
4. **Never edit an already-applied migration** — add a new version instead
5. Type names: PascalCase; property names: snake_case

## Schema Lineage

After every migration, the post-migration hook in `scripts/lib/migrate-common.sh` auto-creates:
- A `{Type}Meta` vertex tracking `type_name`, `migration_file`, `change_type`, `applied_at`
- A `Supersedes` edge from the previous `{Type}Meta` to the new one

Use `reconcile-lineage` to recover if the hook was interrupted after a successful migration.

## Environment Files

- `.env.central` — central ArcadeDB server credentials + `init-db.sh` settings
- `.env.local` — Pi deploy credentials + local embedded DB settings

Copy from `.example` files before first use.
