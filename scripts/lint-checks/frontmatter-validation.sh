#!/usr/bin/env bash
# Frontmatter validation: check required fields
set -euo pipefail

VAULT_ROOT="$1"
WIKI_DIR="$VAULT_ROOT/wiki"

VALID_TYPES="project|entity|concept|decision|guide|summary|worklog|digest|overview|jira"
VALID_STATUS="active|stale|archived"

find "$WIKI_DIR" -name "*.md" -not -name "index.md" -not -name "log.md" | while read -r page; do
  rel_path="${page#$VAULT_ROOT/}"
  errors=""

  # Check frontmatter exists (starts with ---)
  if ! head -1 "$page" | grep -q "^---"; then
    echo "- CRITICAL: \`$rel_path\` — frontmatter missing"
    continue
  fi

  # Extract frontmatter block
  frontmatter=$(sed -n '/^---$/,/^---$/p' "$page" | head -50)

  # Check type field
  type_val=$(echo "$frontmatter" | grep -m1 "^type:" | sed 's/type: *//' | tr -d ' "' || true)
  if [ -z "$type_val" ]; then
    errors="${errors}\n  - type field missing"
  elif ! echo "$type_val" | grep -qE "^($VALID_TYPES)$"; then
    errors="${errors}\n  - type value invalid: $type_val"
  fi

  # Check created field
  if ! echo "$frontmatter" | grep -q "^created:"; then
    errors="${errors}\n  - created field missing"
  fi

  # Check updated field
  if ! echo "$frontmatter" | grep -q "^updated:"; then
    errors="${errors}\n  - updated field missing"
  fi

  # Check status field
  status_val=$(echo "$frontmatter" | grep -m1 "^status:" | sed 's/status: *//' | tr -d ' "' || true)
  if [ -z "$status_val" ]; then
    errors="${errors}\n  - status field missing"
  elif ! echo "$status_val" | grep -qE "^($VALID_STATUS)$"; then
    errors="${errors}\n  - status value invalid: $status_val"
  fi

  if [ -n "$errors" ]; then
    echo -e "- CRITICAL: \`$rel_path\`$errors"
  fi
done
