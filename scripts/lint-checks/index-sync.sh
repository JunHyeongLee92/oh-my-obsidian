#!/usr/bin/env bash
# Index sync: verify every wiki/ page is registered in index.md
set -euo pipefail

VAULT_ROOT="$1"
WIKI_DIR="$VAULT_ROOT/wiki"
INDEX_FILE="$WIKI_DIR/index.md"

if [ ! -f "$INDEX_FILE" ]; then
  echo "- CRITICAL: wiki/index.md not found"
  exit 0
fi

INDEX_CONTENT=$(cat "$INDEX_FILE")

# Check all wiki pages except index.md, log.md, and worklog entries
find "$WIKI_DIR" -name "*.md" \
  -not -name "index.md" \
  -not -name "log.md" \
  -not -path "*/worklog/*" \
  -not -path "*/jira/*" | while read -r page; do

  basename_no_ext="$(basename "$page" .md)"
  rel_path="${page#$VAULT_ROOT/}"

  if ! echo "$INDEX_CONTENT" | grep -q "$basename_no_ext"; then
    echo "- WARN: \`$rel_path\` — not registered in index.md"
  fi
done
