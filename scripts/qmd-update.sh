#!/usr/bin/env bash
set -euo pipefail

# qmd index refresh — runs daily via cron
# qmd uses a static index and does not watch the filesystem in real time.
# New pages only become searchable after periodic update + embed runs.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
VAULT_ROOT="$(omo_get_vault_path)"

readonly VAULT_ROOT
readonly LOG_DIR="${HOME}/.local/state/oh-my-obsidian"
readonly LOG_FILE="${LOG_DIR}/qmd-update.log"
readonly LOCK_DIR="/tmp/oh-my-obsidian-qmd-update.lock"
readonly TIMESTAMP_FORMAT="+%Y-%m-%d %H:%M:%S"

export BUN_INSTALL="${HOME}/.bun"
export PATH="${BUN_INSTALL}/bin:${HOME}/.npm-global/bin:/usr/local/bin:/usr/bin:/bin"

mkdir -p "${LOG_DIR}"

log() {
    printf '[%s] %s\n' "$(date "${TIMESTAMP_FORMAT}")" "$*" | tee -a "${LOG_FILE}"
}

cleanup() {
    local exit_code=$?
    rm -rf "${LOCK_DIR}"
    if [[ ${exit_code} -ne 0 ]]; then
        log "ERROR: qmd-update failed with exit code ${exit_code}"
    fi
    exit "${exit_code}"
}

trap cleanup EXIT

if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
    log "Another qmd-update process is already running; exiting"
    exit 0
fi

if ! command -v qmd &>/dev/null; then
    log "ERROR: qmd not found in PATH"
    exit 127
fi

log "Starting qmd index update on ${VAULT_ROOT}"
cd "${VAULT_ROOT}"

qmd update 2>&1 | tee -a "${LOG_FILE}"
qmd embed 2>&1 | tee -a "${LOG_FILE}"

log "qmd index update complete"
