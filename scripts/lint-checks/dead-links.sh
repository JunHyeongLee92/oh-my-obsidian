#!/usr/bin/env bash
# Detect dead links: [[wiki-link]] that resolve to a non-existent file.
#
# Exclude code examples: [[...]] inside inline backticks (`[[example]]`) and
# fenced code blocks (``` ... ```) are not checked, so documentation can show
# wiki syntax as teaching examples without triggering warnings.
set -euo pipefail

VAULT_ROOT="$1"
WIKI_DIR="$VAULT_ROOT/wiki"
PROJECTS_DIR="$VAULT_ROOT/projects"

# Obsidian wikilinks resolve by filename across the whole vault. Since
# projects/ became a top-level sibling of wiki/ (post-v0.0.1 layout change),
# dead-link targets must be searched in both locations.
TARGET_DIRS=("$WIKI_DIR")
[ -d "$PROJECTS_DIR" ] && TARGET_DIRS+=("$PROJECTS_DIR")

find "$WIKI_DIR" -name "*.md" | while read -r page; do
  rel_path="${page#$VAULT_ROOT/}"

  # 1) Exclude fenced code blocks (toggle on lines starting with ```, drop lines inside)
  # 2) Strip inline backticks (`...`, within a single line only)
  # 3) Extract [[link]] targets from the remaining text (also supports [[link|display]])
  awk '/^```/{flag=!flag; next} !flag' "$page" \
    | sed 's/`[^`]*`//g' \
    | { grep -oE '\[\[[^]|]+' || true; } \
    | sed 's/\[\[//' \
    | while read -r link; do
        [ -z "$link" ] && continue

        # Search wiki/ and (when present) projects/ for the target file:
        # file.md, folder/index.md, folder/file.md
        found=$(find "${TARGET_DIRS[@]}" \( -name "${link}.md" -o -path "*/${link}/index.md" -o -path "*/${link}.md" \) 2>/dev/null | head -1)

        if [ -z "$found" ]; then
          echo "- CRITICAL: \`$rel_path\` — dead link: [[$link]]"
        fi
      done
done
