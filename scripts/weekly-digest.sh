#!/usr/bin/env bash
set -euo pipefail

# Weekly Digest — re-synthesize the wiki every Monday 03:30
# Claude Code generates the content; bash orchestrates the call.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
VAULT_ROOT="$(omo_get_vault_path)"
WIKI_DIR="$VAULT_ROOT/wiki"
LOG_FILE="$WIKI_DIR/log.md"
DIGEST_DIR="$WIKI_DIR/digests"
YEAR_WEEK="$(date +%Y-W%V)"
DIGEST_FILE="$DIGEST_DIR/$YEAR_WEEK.md"

export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"

mkdir -p "$DIGEST_DIR"

# Skip if this week's digest already exists
if [ -f "$DIGEST_FILE" ]; then
  echo "This week's digest already exists: $DIGEST_FILE"
  exit 0
fi

# Compute Monday of the current week
MONDAY=$(date -d "last monday" +%Y-%m-%d 2>/dev/null || date -d "monday - 7 days" +%Y-%m-%d)
TODAY=$(date +%Y-%m-%d)

# Ask Claude Code to generate the digest
CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude || true)}"

if [ -z "$CLAUDE_BIN" ]; then
  echo "ERROR: claude not found in PATH"
  exit 127
fi

$CLAUDE_BIN -p --output-format text "
Work against the vault at $VAULT_ROOT.

Read wiki/log.md and analyze the changes between $MONDAY and $TODAY, then
write a weekly re-synthesis page at wiki/digests/$YEAR_WEEK.md.

Required: before writing, read the 'Digest Page' section in the oh-my-obsidian plugin's schema/wiki-rules.md and schema/page-types.md, and follow the section structure and frontmatter schema defined there. Set the 'week' field to $YEAR_WEEK and 'created' to $TODAY.

Link consistency: when the body mentions a project / entity / concept page, always use the [[wiki-link]] form if the target page exists. Do not mix linked and plain-text mentions within the same table or section.

After completion, also update wiki/index.md and wiki/log.md.
"

echo "Weekly digest generated: $DIGEST_FILE"
