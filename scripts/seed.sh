#!/usr/bin/env bash
# Seed the nomon_central database with test data.
#
# Usage:
#   ./scripts/seed.sh
#
# Creates:
#   - Test user: test@nomon.dev (password: testpassword123)
#   - Test vehicle: NOMON-TEST-001, explorer-v1
#   - OwnsDevice edge linking user → vehicle
#
# Idempotent: checks for existing records before inserting.
#
# Environment variables:
#   ARCADEDB_HOST          — ArcadeDB server hostname (default: localhost)
#   ARCADEDB_HTTP_PORT     — ArcadeDB HTTP API port (default: 2480)
#   ARCADEDB_ROOT_PASSWORD — ArcadeDB root password (default: testpassword)

set -euo pipefail

ARCADEDB_HOST="${ARCADEDB_HOST:-localhost}"
ARCADEDB_HTTP_PORT="${ARCADEDB_HTTP_PORT:-2480}"
ARCADEDB_ROOT_PASSWORD="${ARCADEDB_ROOT_PASSWORD:-testpassword}"

BASE_URL="http://${ARCADEDB_HOST}:${ARCADEDB_HTTP_PORT}"
API_URL="${BASE_URL}/api/v1/command/nomon_central"
AUTH="root:${ARCADEDB_ROOT_PASSWORD}"

# Pre-generated bcrypt hash of "testpassword123" (10 rounds)
TEST_PASSWORD_HASH='$2b$10$7xYbWolLGj/pkV7gSTPgIeXCrC93VLuhEzCL.yIR3EGKSMw14QKFO'

run_sql() {
    local sql="$1"
    curl -s \
        -u "$AUTH" \
        -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -d "{\"language\": \"sql\", \"command\": \"${sql}\"}"
}

record_count() {
    local sql="$1"
    local result
    result=$(run_sql "$sql")
    # ArcadeDB returns result array; extract count from first record
    echo "$result" | grep -o '"count":[0-9]*' | head -1 | grep -o '[0-9]*' || echo "0"
}

echo "==> Seeding nomon_central with test data ..."

# --- Test User ---
echo "--- Checking for test user (test@nomon.dev) ..."
USER_COUNT=$(record_count "SELECT count(*) as count FROM User WHERE email = 'test@nomon.dev'")

if [ "$USER_COUNT" -gt 0 ] 2>/dev/null; then
    echo "    Test user already exists, skipping."
else
    echo "    Inserting test user ..."
    run_sql "INSERT INTO User SET email = 'test@nomon.dev', display_name = 'Test User', password_hash = '${TEST_PASSWORD_HASH}', created_at = sysdate(), active = true" > /dev/null
    echo "    Test user created."
fi

# --- Test Vehicle ---
echo "--- Checking for test vehicle (NOMON-TEST-001) ..."
VEHICLE_COUNT=$(record_count "SELECT count(*) as count FROM Vehicle WHERE vin = 'NOMON-TEST-001'")

if [ "$VEHICLE_COUNT" -gt 0 ] 2>/dev/null; then
    echo "    Test vehicle already exists, skipping."
else
    echo "    Inserting test vehicle ..."
    run_sql "INSERT INTO Vehicle SET vin = 'NOMON-TEST-001', model = 'explorer-v1', registered_at = sysdate()" > /dev/null
    echo "    Test vehicle created."
fi

# --- OwnsDevice Edge ---
echo "--- Checking for OwnsDevice edge ..."
EDGE_COUNT=$(record_count "SELECT count(*) as count FROM OwnsDevice WHERE in.vin = 'NOMON-TEST-001' AND out.email = 'test@nomon.dev'")

if [ "$EDGE_COUNT" -gt 0 ] 2>/dev/null; then
    echo "    OwnsDevice edge already exists, skipping."
else
    echo "    Creating OwnsDevice edge ..."
    run_sql "CREATE EDGE OwnsDevice FROM (SELECT FROM User WHERE email = 'test@nomon.dev') TO (SELECT FROM Vehicle WHERE vin = 'NOMON-TEST-001') SET registered_at = sysdate(), role = 'owner'" > /dev/null
    echo "    OwnsDevice edge created."
fi

echo "==> Seeding complete."
