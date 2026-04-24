#!/usr/bin/env bash
# Detect empty pages: frontmatter only, no body content
set -euo pipefail

VAULT_ROOT="$1"
WIKI_DIR="$VAULT_ROOT/wiki"

find "$WIKI_DIR" -name "*.md" -not -name "index.md" -not -name "log.md" | while read -r page; do
  # Extract body (everything after second ---)
  body=$(sed -n '/^---$/,/^---$/d; p' "$page" | sed '/^$/d')

  if [ -z "$body" ]; then
    rel_path="${page#$VAULT_ROOT/}"
    echo "- WARN: \`$rel_path\` — frontmatter only, no body"
  fi
done
