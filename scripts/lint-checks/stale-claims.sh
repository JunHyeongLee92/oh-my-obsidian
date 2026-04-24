#!/usr/bin/env bash
# Stale pages: pages whose `updated` date is older than 90 days
set -euo pipefail

VAULT_ROOT="$1"
WIKI_DIR="$VAULT_ROOT/wiki"
THRESHOLD_DAYS=90
TODAY_EPOCH=$(date +%s)

find "$WIKI_DIR" -name "*.md" -not -name "index.md" -not -name "log.md" | while read -r page; do
  # Skip archived pages
  if grep -q "status: archived" "$page" 2>/dev/null; then
    continue
  fi

  # Extract updated date from frontmatter
  updated=$(grep -m1 "^updated:" "$page" 2>/dev/null | sed 's/updated: *//' | tr -d ' "' || true)

  if [ -z "$updated" ]; then
    continue
  fi

  # Calculate age in days
  updated_epoch=$(date -d "$updated" +%s 2>/dev/null || true)
  if [ -z "$updated_epoch" ]; then
    continue
  fi

  age_days=$(( (TODAY_EPOCH - updated_epoch) / 86400 ))

  if [ "$age_days" -ge "$THRESHOLD_DAYS" ]; then
    rel_path="${page#$VAULT_ROOT/}"
    echo "- WARN: \`$rel_path\` — ${age_days} days stale (last updated: $updated)"
  fi
done
