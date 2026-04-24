#!/usr/bin/env bash
# install-cron.sh — register oh-my-obsidian cron jobs
#
# Registered jobs (default schedule):
#   - lint.sh          daily 03:00
#   - qmd-update.sh    daily 03:15
#   - weekly-digest.sh every Monday 03:30
#
# Override the schedule via env vars:
#   OMO_LINT_CRON_SCHEDULE
#   OMO_QMD_CRON_SCHEDULE
#   OMO_DIGEST_CRON_SCHEDULE
#
# git-sync.sh is intentionally excluded from auto-registration. A fresh vault
# usually has no git remote / credentials set up, so sync would just keep
# failing. After connecting a remote, see the README "Git auto-backup
# (optional)" section to register it manually.
#
# Each cron line is identified by a unique tag (# OMO-CRON:<name>); re-running
# this script replaces only existing OMO entries and preserves the user's
# other cron jobs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
VAULT_ROOT="$(omo_get_vault_path)"
LOG_DIR="$VAULT_ROOT/_ops/lint-reports"
mkdir -p "$LOG_DIR"

LINT_CRON="${OMO_LINT_CRON_SCHEDULE:-0 3 * * *}"
QMD_CRON="${OMO_QMD_CRON_SCHEDULE:-15 3 * * *}"
DIGEST_CRON="${OMO_DIGEST_CRON_SCHEDULE:-30 3 * * 1}"

LINT_LINE="$LINT_CRON bash $SCRIPT_DIR/lint.sh >> $LOG_DIR/cron.log 2>&1 # OMO-CRON:lint"
QMD_LINE="$QMD_CRON bash $SCRIPT_DIR/qmd-update.sh >> $HOME/.local/state/oh-my-obsidian/qmd-update.log 2>&1 # OMO-CRON:qmd"
DIGEST_LINE="$DIGEST_CRON bash $SCRIPT_DIR/weekly-digest.sh >> $HOME/.local/state/oh-my-obsidian/weekly-digest.log 2>&1 # OMO-CRON:digest"

# Read existing crontab (empty string if none)
current_crontab="$(crontab -l 2>/dev/null || true)"

# Start from a state where only OMO-CRON-tagged lines have been removed
filtered="$(printf '%s\n' "$current_crontab" | grep -v '# OMO-CRON:' || true)"

# Append new entries
{
  printf '%s\n' "$filtered"
  printf '%s\n' "$LINT_LINE"
  printf '%s\n' "$QMD_LINE"
  printf '%s\n' "$DIGEST_LINE"
} | sed '/^$/d' | crontab -

mkdir -p "$HOME/.local/state/oh-my-obsidian"

echo "oh-my-obsidian cron jobs installed:"
echo "  vault: $VAULT_ROOT"
echo "  scripts root: $SCRIPT_DIR"
echo ""
echo "  [lint]   $LINT_CRON"
echo "  [qmd]    $QMD_CRON"
echo "  [digest] $DIGEST_CRON"
echo ""
echo "Verify: crontab -l | grep OMO-CRON"
echo ""
echo "Note: git-sync is not auto-registered. After connecting a git remote to"
echo "      your vault, see the README 'Git auto-backup (optional)' section to"
echo "      register it manually if needed."
