#!/usr/bin/env bash
# uninstall-cron.sh — remove oh-my-obsidian cron jobs
#
# Removes only cron entries tagged with # OMO-CRON:<name>.
# The user's other cron entries are preserved.

set -euo pipefail

current_crontab="$(crontab -l 2>/dev/null || true)"

if [ -z "$current_crontab" ]; then
  echo "crontab is empty. Nothing to remove."
  exit 0
fi

removed_count="$(printf '%s\n' "$current_crontab" | grep -c '# OMO-CRON:' || true)"

if [ "$removed_count" -eq 0 ]; then
  echo "No OMO cron entries found."
  exit 0
fi

filtered="$(printf '%s\n' "$current_crontab" | grep -v '# OMO-CRON:' || true)"

if [ -z "$filtered" ]; then
  # Delete the entire crontab when nothing would remain
  crontab -r 2>/dev/null || true
else
  printf '%s\n' "$filtered" | sed '/^$/d' | crontab -
fi

echo "oh-my-obsidian cron removed: ${removed_count} entries deleted"
