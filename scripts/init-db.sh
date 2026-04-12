#!/usr/bin/env bash
# Initialize nomon databases: create instances and run migrations.
#
# Usage:
#   ./scripts/init-db.sh [central|local|all]
#
# Default: all (creates and migrates both central and local databases)
#
# Environment variables:
#   ARCADEDB_HOST          — ArcadeDB server hostname (default: localhost)
#   ARCADEDB_HTTP_PORT     — ArcadeDB HTTP API port (default: 2480)
#   ARCADEDB_ROOT_PASSWORD — ArcadeDB root password (default: testpassword)
#   ARCADEDB_LOCAL_DATA    — Path for local embedded data (default: local/data)
#   INIT_DB_RETRIES        — Max health-check retries (default: 30)
#   INIT_DB_RETRY_DELAY    — Seconds between retries (default: 2)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET="${1:-all}"

ARCADEDB_HOST="${ARCADEDB_HOST:-localhost}"
ARCADEDB_HTTP_PORT="${ARCADEDB_HTTP_PORT:-2480}"
ARCADEDB_ROOT_PASSWORD="${ARCADEDB_ROOT_PASSWORD:-testpassword}"
ARCADEDB_LOCAL_DATA="${ARCADEDB_LOCAL_DATA:-local/data}"
INIT_DB_RETRIES="${INIT_DB_RETRIES:-30}"
INIT_DB_RETRY_DELAY="${INIT_DB_RETRY_DELAY:-2}"

BASE_URL="http://${ARCADEDB_HOST}:${ARCADEDB_HTTP_PORT}"

usage() {
    echo "Usage: $0 [central|local|all]"
    echo ""
    echo "Initialize nomon databases and run Flyway migrations."
    echo ""
    echo "Arguments:"
    echo "  central    Create and migrate central database only"
    echo "  local      Create and migrate local database only"
    echo "  all        Create and migrate both databases (default)"
    exit 1
}

wait_for_arcadedb() {
    echo "==> Waiting for ArcadeDB at ${BASE_URL} ..."
    local attempt=0
    while [ "$attempt" -lt "$INIT_DB_RETRIES" ]; do
        if curl -sf "${BASE_URL}/api/v1/ready" > /dev/null 2>&1; then
            echo "==> ArcadeDB is ready."
            return 0
        fi
        attempt=$((attempt + 1))
        echo "    Attempt ${attempt}/${INIT_DB_RETRIES} — not ready, retrying in ${INIT_DB_RETRY_DELAY}s ..."
        sleep "$INIT_DB_RETRY_DELAY"
    done
    echo "Error: ArcadeDB did not become ready after ${INIT_DB_RETRIES} attempts."
    exit 1
}

create_central_database() {
    echo "==> Creating nomon_central database ..."
    local response
    local http_code
    # Capture both body and status code in a single request
    response=$(curl -s -w "\n%{http_code}" \
        -u "root:${ARCADEDB_ROOT_PASSWORD}" \
        -X POST "${BASE_URL}/api/v1/server" \
        -H "Content-Type: application/json" \
        -d '{"command": "create database nomon_central"}')
    http_code=$(echo "$response" | tail -1)
    response=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ]; then
        echo "    nomon_central created."
    elif [ "$http_code" = "400" ] && echo "$response" | grep -qi "already exists"; then
        echo "    nomon_central already exists, skipping."
    else
        echo "Error: failed to create nomon_central (HTTP ${http_code}): ${response}"
        exit 1
    fi
}

create_local_database() {
    echo "==> Creating local data directory at ${ARCADEDB_LOCAL_DATA} ..."
    mkdir -p "${PROJECT_DIR}/${ARCADEDB_LOCAL_DATA}"
    echo "    Local data directory ready."
}

init_central() {
    wait_for_arcadedb
    create_central_database
    echo "==> Running central migrations ..."
    ARCADEDB_PASSWORD="$ARCADEDB_ROOT_PASSWORD" \
        "$SCRIPT_DIR/migrate.sh" central migrate
}

init_local() {
    create_local_database
    echo "==> Running local migrations ..."
    ARCADEDB_LOCAL_DATA="$ARCADEDB_LOCAL_DATA" \
        "$SCRIPT_DIR/migrate.sh" local migrate
}

case "$TARGET" in
    central)
        init_central
        ;;
    local)
        init_local
        ;;
    all)
        init_central
        init_local
        ;;
    *)
        echo "Error: unknown target '${TARGET}'."
        usage
        ;;
esac

echo "==> Database initialization complete."
