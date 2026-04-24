#!/usr/bin/env bash
# Detect unescaped alias-pipe wikilinks inside tables.
# [[path|alias]] inside a markdown table row (| ... |) collides with the column separator.
set -euo pipefail

VAULT_ROOT="$1"
WIKI_DIR="$VAULT_ROOT/wiki"

find "$WIKI_DIR" -name "*.md" | while read -r page; do
  rel_path="${page#$VAULT_ROOT/}"

  # Extract lines in table rows (starting with `|`) that contain unescaped `[[...|...]]`.
  # `\|` is an escaped pipe and is ignored.
  awk '
    /^[[:space:]]*\|/ {
      line = $0
      # Temporarily substitute escaped pipes so only unescaped pipes are checked
      gsub(/\\\|/, "\x01", line)
      if (match(line, /\[\[[^][]*\|[^][]*\]\]/)) {
        printf("%d:%s\n", NR, $0)
      }
    }
  ' "$page" | while IFS=: read -r lineno content; do
    echo "- WARN: \`$rel_path:$lineno\` — unescaped wikilink pipe inside table: \`${content## }\`"
  done
done
