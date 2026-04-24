#!/usr/bin/env bash
# Missing cross-references: pages with fewer than 2 outgoing wikilinks
set -euo pipefail

VAULT_ROOT="$1"
WIKI_DIR="$VAULT_ROOT/wiki"

find "$WIKI_DIR" -name "*.md" -not -name "index.md" -not -name "log.md" | while read -r page; do
  rel_path="${page#$VAULT_ROOT/}"
  # Count occurrences (accurate even when a line has multiple wikilinks)
  link_count=$(grep -oE '\[\[[^]]+\]\]' "$page" 2>/dev/null | wc -l | tr -d ' ')
  link_count="${link_count:-0}"
  link_count=$((link_count + 0))

  # worklog pages need only 1 link
  if echo "$rel_path" | grep -q "worklog/"; then
    if [ "$link_count" -lt 1 ]; then
      echo "- INFO: \`$rel_path\` — no outgoing links (at least 1 required)"
    fi
  else
    if [ "$link_count" -lt 2 ]; then
      echo "- INFO: \`$rel_path\` — ${link_count} outgoing links (at least 2 recommended)"
    fi
  fi
done
