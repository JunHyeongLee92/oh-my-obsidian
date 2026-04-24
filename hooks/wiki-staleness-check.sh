#!/usr/bin/env bash
# wiki-staleness-check-version: 2
# PostToolUse(Bash) hook: warn when a project's linked wiki page is stale.
#
# Fires on `git commit` in a project repo that declares `project-name: <name>`
# in its CLAUDE.md. Resolves the wiki path via OMO config
# (~/.config/oh-my-obsidian/config.json → vaultPath), then checks whether
# <vault>/projects/<name>/index.md's `updated:` frontmatter is older
# than recent feat/fix/refactor commits in the source repo.
#
# - Emits stderr warning + exit 2 when a warning fires (Claude sees it as
#   tool feedback).
# - Silent exit 0 in all no-op paths.
# - Opt-in: projects without `project-name:` line are skipped.
# - Legacy `위키 경로:` key is NOT supported (clean break post-plugin).
#
# Requires: bash, git, grep, awk, jq, node.

set -uo pipefail

OMO_CONFIG_PATH="${OMO_CONFIG_PATH:-$HOME/.config/oh-my-obsidian/config.json}"

# Read stdin once. Always reprint it on exit so downstream hooks stay intact.
INPUT=$(cat)
trap 'printf "%s" "$INPUT"' EXIT

# Hard deps: jq, node.
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi
if ! command -v node >/dev/null 2>&1; then
  exit 0
fi

CMD=$(printf "%s" "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
CWD=$(printf "%s" "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$CWD" ] && CWD="$PWD"

# Only react to actual `git commit` invocations.
case "$CMD" in
  *"git commit"*|*"git "*" commit"*) ;;
  *) exit 0 ;;
esac

# Resolve vaultPath from OMO config. If config missing, silent exit (plugin
# not initialized → nothing to check against).
[ -f "$OMO_CONFIG_PATH" ] || exit 0
VAULT_ROOT=$(node -e "
  try {
    const cfg = JSON.parse(require('fs').readFileSync('$OMO_CONFIG_PATH', 'utf8'));
    process.stdout.write(cfg.vaultPath || '');
  } catch (e) {}
" 2>/dev/null)
[ -z "$VAULT_ROOT" ] && exit 0

# Skip commits inside the vault itself (auto-backup / vault self-maintenance).
case "$CWD" in
  "$VAULT_ROOT"|"$VAULT_ROOT"/*) exit 0 ;;
esac

# Resolve repo root; bail if not a git repo.
REPO_ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null) || exit 0

PROJECT_CLAUDE_MD="$REPO_ROOT/CLAUDE.md"
[ -f "$PROJECT_CLAUDE_MD" ] || exit 0

# Extract `project-name: <name>` from project CLAUDE.md.
# Line shape examples:
#   project-name: nl2sql
#   - project-name: nl2sql
#   * project-name: `nl2sql`
PROJECT_NAME=$(grep -E "^[-*[:space:]]*project-name[[:space:]]*:" "$PROJECT_CLAUDE_MD" 2>/dev/null \
  | head -1 \
  | sed -E 's#^[-*[:space:]]*project-name[[:space:]]*:[[:space:]]*##' \
  | sed -E 's#^[`"'"'"']+##; s#[`"'"'"']+$##' \
  | sed -E 's#[[:space:]]+$##')

# Opt-in: no project-name → silent skip.
[ -z "$PROJECT_NAME" ] && exit 0

WIKI_DIR="$VAULT_ROOT/projects/$PROJECT_NAME"
WIKI_INDEX="$WIKI_DIR/index.md"

# Case: project-name declared but wiki index missing → strong warn.
if [ ! -f "$WIKI_INDEX" ]; then
  {
    echo "[wiki-check] ⚠️ wiki page missing: $WIKI_INDEX"
    echo "- project CLAUDE.md declares 'project-name: $PROJECT_NAME' but no matching page exists in the vault"
    echo "- Fix: run /omo-project-add to create the project page in the vault."
  } >&2
  exit 2
fi

# Extract `updated: YYYY-MM-DD` from frontmatter.
UPDATED=$(awk '
  /^---[[:space:]]*$/ { fm = !fm; next }
  fm && /^updated[[:space:]]*:/ {
    sub(/^updated[[:space:]]*:[[:space:]]*/, "")
    gsub(/"/, "")
    gsub(/[[:space:]]+$/, "")
    print
    exit
  }
' "$WIKI_INDEX")

# Fallback: missing/unparseable date → maximally stale.
if ! echo "$UPDATED" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
  UPDATED="1970-01-01"
fi

# Count feat/fix/refactor commits in the source repo since `updated`.
COMMIT_SUBJECTS=$(git -C "$REPO_ROOT" log \
  --since="$UPDATED" \
  --format='%s' \
  --perl-regexp \
  --grep='^(feat|fix|refactor)(\([^)]+\))?!?:' \
  2>/dev/null)

[ -z "$COMMIT_SUBJECTS" ] && exit 0

COMMIT_COUNT=$(printf "%s\n" "$COMMIT_SUBJECTS" | grep -c .)

{
  echo "[wiki-check] ⚠️ wiki stale: $WIKI_DIR"
  echo "- updated: $UPDATED, with $COMMIT_COUNT feat/fix/refactor commit(s) since"
  echo "- Last 3:"
  printf "%s\n" "$COMMIT_SUBJECTS" | head -3 | sed 's/^/    • /'
  echo "- Fix: run /omo-project-update $PROJECT_NAME to read recent commits, rewrite the index Current state, bump updated, and optionally draft worklog/decisions — all in one shot."
  echo "- Manual: edit the 'updated' field and 'Current state' section of index.md directly (see <plugin>/schema/wiki-rules.md)"
} >&2

exit 2
