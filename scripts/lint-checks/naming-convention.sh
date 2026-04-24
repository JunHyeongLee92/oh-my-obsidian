#!/usr/bin/env bash
# Naming-convention check: kebab-case violations (spaces, camelCase, PascalCase)
# Exception: worklog files may use YYYY-MM-DD.md format
set -euo pipefail

VAULT_ROOT="$1"
WIKI_DIR="$VAULT_ROOT/wiki"

find "$WIKI_DIR" -name "*.md" -not -name "index.md" -not -name "log.md" | while read -r page; do
  filename=$(basename "$page" .md)
  rel_path="${page#$VAULT_ROOT/}"

  # worklog files: allow YYYY-MM-DD format
  if echo "$rel_path" | grep -q "worklog/"; then
    if echo "$filename" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
      continue
    fi
  fi

  # digest files: allow YYYY-WNN format
  if echo "$rel_path" | grep -q "digests/"; then
    if echo "$filename" | grep -qE '^[0-9]{4}-W[0-9]{2}$'; then
      continue
    fi
  fi

  # Contains spaces
  if echo "$filename" | grep -q ' '; then
    echo "- INFO: \`$rel_path\` — filename contains spaces"
    continue
  fi

  # Contains uppercase (kebab-case violation) — Korean characters excluded
  if echo "$filename" | grep -q '[A-Z]'; then
    echo "- INFO: \`$rel_path\` — filename contains uppercase (kebab-case violation)"
    continue
  fi
done
