#!/bin/bash

set -euo pipefail

# Obsidian Vault Git Auto Sync Script
# Explicitly sets PATH / log / lock / SSH so it runs reliably under cron.
# Vault path is resolved from ~/.config/oh-my-obsidian/config.json.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
REPO_DIR="$(omo_get_vault_path)"

readonly REPO_DIR
readonly LOG_DIR="${HOME}/.local/state/oh-my-obsidian"
readonly LOG_FILE="${LOG_DIR}/git-sync.log"
readonly LOCK_DIR="/tmp/oh-my-obsidian-git-sync.lock"
readonly TIMESTAMP_FORMAT="+%Y-%m-%d %H:%M:%S"

export PATH="/usr/local/bin:/usr/bin:/bin"

mkdir -p "${LOG_DIR}"

log() {
    printf '[%s] %s\n' "$(date "${TIMESTAMP_FORMAT}")" "$*" | tee -a "${LOG_FILE}"
}

cleanup() {
    local exit_code=$?
    rm -rf "${LOCK_DIR}"
    if [[ ${exit_code} -ne 0 ]]; then
        log "ERROR: git-sync failed with exit code ${exit_code}"
    fi
    exit "${exit_code}"
}

trap cleanup EXIT

if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
    log "Another git-sync process is already running; exiting"
    exit 0
fi

find_ssh_key() {
    local configured_key="${GIT_SYNC_SSH_KEY:-}"
    local candidate

    if [[ -n "${configured_key}" && -r "${configured_key}" ]]; then
        printf '%s\n' "${configured_key}"
        return 0
    fi

    for candidate in "${HOME}/.ssh/id_ed25519" "${HOME}/.ssh/id_rsa"; do
        if [[ -r "${candidate}" ]]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done

    return 1
}

if ssh_key="$(find_ssh_key)"; then
    export GIT_SSH_COMMAND="ssh -i ${ssh_key} -o IdentitiesOnly=yes -o BatchMode=yes"
    log "Using SSH key: ${ssh_key}"
else
    log "No readable SSH key found; relying on existing git/ssh configuration"
fi

log "Starting git-sync on ${REPO_DIR}"
cd "${REPO_DIR}"

# Clean up stale lock files from a prior abnormal exit
rm -f .git/index.lock

log "Fetching latest remote changes"
git fetch --prune origin

if ! git diff --quiet HEAD --; then
    log "Rebasing local uncommitted work onto origin/main with autostash"
fi

git pull --rebase --autostash origin main

git add -A

if git diff --cached --quiet; then
    log "No changes to commit"
    exit 0
fi

commit_message="chore: vault backup $(date '+%Y-%m-%d %H:%M')"
git commit -m "${commit_message}"
git push origin main

log "Changes committed and pushed successfully"

# Refresh qmd index
export BUN_INSTALL="${HOME}/.bun"
export PATH="${BUN_INSTALL}/bin:${PATH}"

if command -v qmd &>/dev/null; then
    log "Updating qmd index"
    qmd update 2>&1 | tail -1 || true
    qmd embed 2>&1 | tail -1 || true
    log "qmd index updated"
fi
