#!/usr/bin/env bash
# Orphan pages: wiki pages that no other wiki page links to
set -euo pipefail

VAULT_ROOT="$1"
WIKI_DIR="$VAULT_ROOT/wiki"

# Collect all wiki markdown files (exclude index.md, log.md at root)
find "$WIKI_DIR" -name "*.md" -not -name "index.md" -not -name "log.md" -not -path "*/worklog/*" -not -path "*/jira/*" | while read -r page; do
  # Get the filename without extension for link matching
  basename_no_ext="$(basename "$page" .md)"

  # Search for [[basename]] or [[path|display]] links in other wiki files
  incoming=$(grep -rl "\[\[.*${basename_no_ext}.*\]\]" "$WIKI_DIR" --include="*.md" 2>/dev/null | grep -v "$page" | head -1 || true)

  if [ -z "$incoming" ]; then
    rel_path="${page#$VAULT_ROOT/}"
    echo "- WARN: \`$rel_path\` — not linked from any other page"
  fi
done
