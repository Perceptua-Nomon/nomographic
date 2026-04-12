#!/usr/bin/env bash
# deploy-local.sh — Deploy local ArcadeDB migrations to a Raspberry Pi.
#
# Usage:
#   ./scripts/deploy-local.sh [<pi-host>]
#
# Arguments:
#   pi-host   SSH host (user@host or plain hostname). Overrides NOMON_PI_HOST.
#             If omitted and NOMON_PI_HOST is unset, runs locally.
#
# Environment:
#   NOMON_PI_HOST       SSH target (overridden by pi-host arg)
#   NOMON_SSH_KEY       Path to SSH private key (optional)
#   NOMON_REMOTE_DIR    Absolute path to nomographic directory on the Pi.
#                       Defaults to ~/perceptua-nomon/nomographic.
#   ARCADEDB_LOCAL_DATA Path for local embedded data (default: local/data).
#
# The script:
#   1. If a pi-host is specified, rsyncs the nomographic directory to the Pi.
#   2. Ensures the local data directory exists.
#   3. Runs local migrations via scripts/migrate.sh.
#
# Exit codes:
#   0  success
#   1  usage / configuration error
#   2  sync or migration failure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

# ── Help ───────────────────────────────────────────────────────────────────────

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    sed -n '2,28p' "$0" | sed 's/^# \?//'
    exit 0
fi

# ── Configuration ──────────────────────────────────────────────────────────────

PI_HOST="${1:-${NOMON_PI_HOST:-}}"
REMOTE_DIR="${NOMON_REMOTE_DIR:-${HOME}/perceptua-nomon/nomographic}"
LOCAL_DATA="${ARCADEDB_LOCAL_DATA:-local/data}"

# ── Sync to Pi (if remote) ────────────────────────────────────────────────────

if [[ -n "${PI_HOST}" ]]; then
    RSYNC_OPTS=(--archive --compress --delete
        --exclude='.git/'
        --exclude='__pycache__/'
        --exclude='*.pyc'
    )

    SSH_CMD="ssh -o StrictHostKeyChecking=accept-new"
    if [[ -n "${NOMON_SSH_KEY:-}" ]]; then
        SSH_CMD+=" -i ${NOMON_SSH_KEY}"
    fi
    RSYNC_OPTS+=(-e "${SSH_CMD}")

    _rsync_dest="${PI_HOST}:${REMOTE_DIR}/"
    echo "==> Syncing nomographic → ${_rsync_dest}..."
    rsync "${RSYNC_OPTS[@]}" "${PROJECT_DIR}/" "${_rsync_dest}"
    echo "  Sync complete ✓"

    # Run migrations remotely
    SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=15)
    if [[ -n "${NOMON_SSH_KEY:-}" ]]; then
        SSH_OPTS+=(-i "${NOMON_SSH_KEY}")
    fi

    echo "==> Running local migrations on ${PI_HOST}..."
    ssh "${SSH_OPTS[@]}" "${PI_HOST}" bash -ls -- "${REMOTE_DIR}" "${LOCAL_DATA}" <<'END_REMOTE'
set -euo pipefail
_remote_dir="${1:-${HOME}/perceptua-nomon/nomographic}"
_local_data="${2:-local/data}"
cd "${_remote_dir}"
mkdir -p "${_local_data}"
echo "  Data directory: ${_local_data} ✓"
./scripts/migrate.sh local migrate
END_REMOTE

    echo "✓ Local database deployed to ${PI_HOST}."
else
    # Run locally
    cd "${PROJECT_DIR}"

    echo "==> Ensuring local data directory exists..."
    mkdir -p "${LOCAL_DATA}"
    echo "  Data directory: ${LOCAL_DATA} ✓"

    echo "==> Running local migrations..."
    ./scripts/migrate.sh local migrate

    echo "✓ Local database migrations applied."
fi
