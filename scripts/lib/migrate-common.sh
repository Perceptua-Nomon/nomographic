#!/usr/bin/env bash
# migrate-common.sh — Shared schema lineage tracking for nomon migration runners.
#
# CONTRACT: This library expects the following functions to be defined
# in the calling script's scope (bash dynamic scoping):
#
#   run_sql "$sql" "$action_description" [$allow_already_exists]
#     — Execute SQL against the target ArcadeDB database.
#       Returns the JSON response body. Exits on failure.
#
#   escape_sql_literal "$value"
#     — Escape single quotes in a SQL literal value.
#
#   record_count "$sql"
#     — Execute a SELECT count(*) query and return the integer count.
#
# Source this file AFTER defining the above functions.

# parse_affected_types — Parse SQL file for affected type names.
#
# Output: newline-delimited type_name:change_type pairs.
# Deduplication priority: created > deleted > modified.
# Excludes: SchemaMigration, types ending in Meta, Supersedes.
#
# NOTE: ALTER TYPE/ALTER PROPERTY statements are not tracked.
# Add patterns here when ALTER-based migrations are introduced.
parse_affected_types() {
    local sql_file="$1"

    # Strip single-line SQL comments before pattern matching
    local filtered
    filtered="$(grep -v '^\s*--' "$sql_file" 2>/dev/null || true)"

    {
        # CREATE VERTEX TYPE <Name> → created
        echo "$filtered" | grep -iE 'CREATE[[:space:]]+VERTEX[[:space:]]+TYPE' 2>/dev/null \
            | sed -E 's/.*CREATE[[:space:]]+VERTEX[[:space:]]+TYPE[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\1:created/' || true

        # CREATE EDGE TYPE <Name> → created
        echo "$filtered" | grep -iE 'CREATE[[:space:]]+EDGE[[:space:]]+TYPE' 2>/dev/null \
            | sed -E 's/.*CREATE[[:space:]]+EDGE[[:space:]]+TYPE[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\1:created/' || true

        # CREATE PROPERTY <Name>.<prop> → modified
        echo "$filtered" | grep -iE 'CREATE[[:space:]]+PROPERTY' 2>/dev/null \
            | sed -E 's/.*CREATE[[:space:]]+PROPERTY[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)\..*/\1:modified/' || true

        # CREATE INDEX ... ON <Name> → modified
        echo "$filtered" | grep -iE 'CREATE[[:space:]]+INDEX' 2>/dev/null \
            | sed -E 's/.*ON[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*\(.*/\1:modified/' || true

        # DROP TYPE <Name> → deleted
        echo "$filtered" | grep -iE 'DROP[[:space:]]+TYPE' 2>/dev/null \
            | sed -E 's/.*DROP[[:space:]]+TYPE[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\1:deleted/' || true

        # DROP PROPERTY <Name>.<prop> → modified
        echo "$filtered" | grep -iE 'DROP[[:space:]]+PROPERTY' 2>/dev/null \
            | sed -E 's/.*DROP[[:space:]]+PROPERTY[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)\..*/\1:modified/' || true
    } | grep -v '^$' \
      | grep -vE '^(SchemaMigration|Supersedes):' \
      | grep -vE '^[^:]*Meta:' \
      | awk -F: '
    # awk always exits 0, so pipefail only risks grep returning 1 on empty input.
    {
        name = $1
        change = $2
        if (!(name in types)) {
            types[name] = change
        } else if (change == "created") {
            types[name] = "created"
        } else if (change == "deleted" && types[name] != "created") {
            types[name] = "deleted"
        }
    }
    END {
        for (name in types) {
            print name ":" types[name]
        }
    }
    ' || true
}

# ensure_supersedes_edge — Create the shared Supersedes edge type.
ensure_supersedes_edge() {
    run_sql "CREATE EDGE TYPE Supersedes IF NOT EXISTS" "create Supersedes edge type" >/dev/null
}

# ensure_meta_type — Create {Type}Meta vertex type with lineage properties.
ensure_meta_type() {
    local type_name="$1"
    local meta_type="${type_name}Meta"
    run_sql "CREATE VERTEX TYPE ${meta_type} IF NOT EXISTS" "create ${meta_type} type" >/dev/null
    run_sql "CREATE PROPERTY ${meta_type}.type_name IF NOT EXISTS STRING" "create ${meta_type}.type_name" >/dev/null
    run_sql "CREATE PROPERTY ${meta_type}.migration_file IF NOT EXISTS STRING" "create ${meta_type}.migration_file" >/dev/null
    run_sql "CREATE PROPERTY ${meta_type}.change_type IF NOT EXISTS STRING" "create ${meta_type}.change_type" >/dev/null
    run_sql "CREATE PROPERTY ${meta_type}.applied_at IF NOT EXISTS DATETIME" "create ${meta_type}.applied_at" >/dev/null
}

# extract_rid — Parse ArcadeDB JSON response to extract @rid from first result.
# Returns empty string (exit 0) if no @rid is found.
extract_rid() {
    local response="$1"
    echo "$response" | grep -o '"@rid":"[^"]*"' | head -1 | sed 's/"@rid":"//;s/"//' || true
}

# record_lineage — Record schema lineage meta-types for a migration file.
#
# Usage: record_lineage <sql_file_path> <repo_relative_migration_path>
record_lineage() {
    local file_path="$1"
    local migration_path="$2"
    local affected_types

    affected_types="$(parse_affected_types "$file_path")"
    if [ -z "$affected_types" ]; then
        return
    fi

    ensure_supersedes_edge

    local escaped_path
    escaped_path="$(escape_sql_literal "$migration_path")"

    while IFS=: read -r type_name change_type; do
        [ -z "$type_name" ] && continue

        local meta_type="${type_name}Meta"
        ensure_meta_type "$type_name"

        # Idempotency: skip if this migration was already recorded
        local count
        count="$(record_count "SELECT count(*) as count FROM ${meta_type} WHERE migration_file = '${escaped_path}'")"
        if [ "${count:-0}" -gt 0 ] 2>/dev/null; then
            continue
        fi

        # Find previous head record
        local escaped_type_name
        escaped_type_name="$(escape_sql_literal "$type_name")"
        local prev_response
        prev_response="$(run_sql "SELECT @rid FROM ${meta_type} WHERE type_name = '${escaped_type_name}' ORDER BY applied_at DESC LIMIT 1" "find previous ${meta_type} head")"
        local prev_rid
        prev_rid="$(extract_rid "$prev_response")"

        # Insert new meta record
        local escaped_change_type
        escaped_change_type="$(escape_sql_literal "$change_type")"
        local insert_response
        insert_response="$(run_sql "INSERT INTO ${meta_type} SET type_name = '${escaped_type_name}', migration_file = '${escaped_path}', change_type = '${escaped_change_type}', applied_at = sysdate()" "insert ${meta_type} record")"
        local new_rid
        new_rid="$(extract_rid "$insert_response")"

        # Link to previous head via Supersedes edge
        if [ -n "$prev_rid" ] && [ -n "$new_rid" ]; then
            run_sql "CREATE EDGE Supersedes FROM ${prev_rid} TO ${new_rid}" "create Supersedes edge for ${type_name}" >/dev/null
        fi
    done <<< "$affected_types"
}

# reconcile_all_lineage — Re-record lineage for all applied migrations.
#
# Iterates over SchemaMigration records and calls record_lineage for each.
# Safe to run repeatedly — per-type idempotency checks skip existing records.
#
# Requires MIGRATIONS_DIR and REPO_RELATIVE_PREFIX to be set by the caller.
reconcile_all_lineage() {
    local result
    result="$(run_sql "SELECT version, script FROM SchemaMigration ORDER BY version" "list applied migrations")"

    local scripts
    scripts="$(echo "$result" | grep -o '"script":"[^"]*"' | sed 's/"script":"//;s/"//' || true)"

    if [ -z "$scripts" ]; then
        echo "==> No applied migrations found. Nothing to reconcile."
        return
    fi

    local reconciled=0
    while IFS= read -r script_name; do
        [ -z "$script_name" ] && continue
        local file_path="${MIGRATIONS_DIR}/${script_name}"
        local repo_relative="${REPO_RELATIVE_PREFIX}/${script_name}"

        if [ ! -f "$file_path" ]; then
            echo "  [warn] migration file not found: ${file_path}"
            continue
        fi

        echo "  [reconcile] ${script_name}"
        record_lineage "$file_path" "$repo_relative"
        reconciled=$((reconciled + 1))
    done <<< "$scripts"

    echo "==> Lineage reconciliation complete (${reconciled} migrations processed)."
}
