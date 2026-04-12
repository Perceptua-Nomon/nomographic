#!/usr/bin/env bash
# Run Flyway migrations for a nomon database instance.
#
# Usage:
#   ./scripts/migrate.sh central [migrate|validate|info]
#   ./scripts/migrate.sh local   [migrate|validate|info]
#
# Environment variables:
#   ARCADEDB_HOST       — ArcadeDB server hostname (default: localhost)
#   ARCADEDB_BINARY_PORT — ArcadeDB binary protocol port (default: 2424)
#   ARCADEDB_USER       — Database user (default: root)
#   ARCADEDB_PASSWORD   — Database password (default: testpassword)
#   ARCADEDB_LOCAL_DATA — Path for local embedded data (default: local/data)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
    echo "Usage: $0 <central|local> [migrate|validate|info]"
    echo ""
    echo "Run Flyway migrations for a nomon database instance."
    echo ""
    echo "Arguments:"
    echo "  central|local    Target database instance"
    echo "  migrate          Apply pending migrations (default)"
    echo "  validate         Check migration consistency"
    echo "  info             Show migration status"
    exit 1
}

if [ $# -lt 1 ]; then
    usage
fi

INSTANCE="$1"
SUBCOMMAND="${2:-migrate}"

ARCADEDB_HOST="${ARCADEDB_HOST:-localhost}"
ARCADEDB_BINARY_PORT="${ARCADEDB_BINARY_PORT:-2424}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASSWORD="${ARCADEDB_PASSWORD:-testpassword}"
ARCADEDB_LOCAL_DATA="${ARCADEDB_LOCAL_DATA:-local/data}"

case "$INSTANCE" in
    central)
        CONFIG_FILE="central/flyway.toml"
        JDBC_URL="jdbc:arcadedb:remote:${ARCADEDB_HOST}:${ARCADEDB_BINARY_PORT}/nomon_central"
        ;;
    local)
        CONFIG_FILE="local/flyway.toml"
        JDBC_URL="jdbc:arcadedb:${ARCADEDB_LOCAL_DATA}/nomon_local"
        ;;
    *)
        echo "Error: unknown instance '${INSTANCE}'. Must be 'central' or 'local'."
        usage
        ;;
esac

case "$SUBCOMMAND" in
    migrate|validate|info)
        ;;
    *)
        echo "Error: unknown subcommand '${SUBCOMMAND}'. Must be 'migrate', 'validate', or 'info'."
        usage
        ;;
esac

cd "$PROJECT_DIR"

echo "==> Flyway ${SUBCOMMAND} for ${INSTANCE}"
echo "    Config:   ${CONFIG_FILE}"
echo "    JDBC URL: ${JDBC_URL}"

FLYWAY_ARGS=(
    -configFiles="$CONFIG_FILE"
    -url="$JDBC_URL"
)

if [ "$INSTANCE" = "central" ]; then
    FLYWAY_ARGS+=(
        -user="$ARCADEDB_USER"
        -password="$ARCADEDB_PASSWORD"
    )
fi

flyway "${FLYWAY_ARGS[@]}" "$SUBCOMMAND"

echo "==> Flyway ${SUBCOMMAND} for ${INSTANCE} complete."
