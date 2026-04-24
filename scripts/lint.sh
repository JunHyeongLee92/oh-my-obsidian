#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
VAULT_ROOT="$(omo_get_vault_path)"
WIKI_DIR="$VAULT_ROOT/wiki"
CHECKS_DIR="$SCRIPT_DIR/lint-checks"
REPORTS_DIR="$VAULT_ROOT/_ops/lint-reports"
TIMESTAMP="$(date +%Y-%m-%d_%H%M%S)"
REPORT_FILE="$REPORTS_DIR/lint-$TIMESTAMP.md"
# Per-hostname latest file — avoids conflicts when multiple machines share the vault
HOSTNAME_SAFE="$(hostname -s | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' | sed 's/-*$//')"
LATEST_FILE="$REPORTS_DIR/latest-$HOSTNAME_SAFE.md"
RETENTION_DAYS="${LINT_REPORT_RETENTION_DAYS:-7}"

# Status document content temp file (no timestamp)
STATUS_TMP="$(mktemp)"
trap 'rm -f "$STATUS_TMP"' EXIT

mkdir -p "$REPORTS_DIR"

# Status header (no timestamp — identical content means no git diff)
cat > "$STATUS_TMP" <<'EOF'
---
type: lint-report
---

# Lint Report

EOF

CRITICAL_COUNT=0
WARN_COUNT=0
INFO_COUNT=0

# Run each check script
for check in "$CHECKS_DIR"/*.sh; do
  [ -f "$check" ] || continue
  check_name="$(basename "$check" .sh)"

  echo "## $check_name" >> "$STATUS_TMP"
  echo "" >> "$STATUS_TMP"

  if output="$(bash "$check" "$VAULT_ROOT" 2>&1)"; then
    if [ -z "$output" ]; then
      echo "passed" >> "$STATUS_TMP"
    else
      echo "$output" >> "$STATUS_TMP"
    fi
  else
    echo "$output" >> "$STATUS_TMP"
  fi

  echo "" >> "$STATUS_TMP"

  # Count severities
  if [ -n "$output" ]; then
    CRITICAL_COUNT=$((CRITICAL_COUNT + $(echo "$output" | grep -c "CRITICAL" || true)))
    WARN_COUNT=$((WARN_COUNT + $(echo "$output" | grep -c "WARN" || true)))
    INFO_COUNT=$((INFO_COUNT + $(echo "$output" | grep -c "INFO" || true)))
  fi
done

# Summary
cat >> "$STATUS_TMP" <<EOF
---

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | $CRITICAL_COUNT |
| WARN | $WARN_COUNT |
| INFO | $INFO_COUNT |
EOF

# Status doc: overwrite only when content changed (preserves mtime → no git diff → no auto-commit)
if [ ! -f "$LATEST_FILE" ] || ! cmp -s "$STATUS_TMP" "$LATEST_FILE"; then
  cp "$STATUS_TMP" "$LATEST_FILE"
  LATEST_UPDATED=1
else
  LATEST_UPDATED=0
fi

# Local timestamped report: includes timestamp in header, gitignored
{
  cat <<EOF
---
type: lint-report
date: $(date +%Y-%m-%d)
---

# Lint Report — $(date +%Y-%m-%d\ %H:%M)

EOF
  # Skip STATUS_TMP's first 6 lines (frontmatter + title) and append body
  tail -n +7 "$STATUS_TMP"
} > "$REPORT_FILE"

# Retention: auto-delete old timestamped reports (excluding latest-*.md / .gitkeep / cron.log)
find "$REPORTS_DIR" -maxdepth 1 -name "lint-*.md" -mtime "+$RETENTION_DAYS" -delete 2>/dev/null || true

echo "Lint complete: $REPORT_FILE"
if [ "$LATEST_UPDATED" -eq 1 ]; then
  echo "Status doc updated: $LATEST_FILE"
else
  echo "Status doc unchanged (content identical)"
fi
echo "CRITICAL=$CRITICAL_COUNT WARN=$WARN_COUNT INFO=$INFO_COUNT"

# Exit non-zero if critical issues found
[ "$CRITICAL_COUNT" -eq 0 ]
