#!/usr/bin/env bash
set -euo pipefail

# clip.sh — extract the original content from a URL and save it under <vault>/_sources/
# Render with Playwright (headless browser) → convert to markdown with Defuddle (no AI processing)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
VAULT_ROOT="$(omo_get_vault_path)"

if [ $# -lt 1 ]; then
  echo "Usage: clip.sh <URL> [category] [filename]"
  echo "  category: articles (default), papers, conversations, misc"
  echo "  filename: auto-generated from title if not specified"
  exit 1
fi

URL="$1"
CATEGORY="${2:-articles}"
FILENAME="${3:-}"
TODAY=$(date +%Y-%m-%d)
TMP_HTML="/tmp/clip-$$-$(date +%s).html"
TMP_JS="/tmp/clip-$$-pw.mjs"

SOURCES_DIR="$VAULT_ROOT/_sources/$CATEGORY"
mkdir -p "$SOURCES_DIR"

echo "Extracting: $URL"

# 1. Resolve Playwright global install path at runtime (works across machines)
if ! command -v npm >/dev/null 2>&1; then
  echo "ERROR: npm not found. Install Node.js."
  exit 1
fi

PLAYWRIGHT_PATH="$(npm root -g)/playwright/index.mjs"
if [ ! -f "$PLAYWRIGHT_PATH" ]; then
  echo "ERROR: playwright global install missing: $PLAYWRIGHT_PATH"
  echo "Run: npm install -g playwright && npx playwright install chromium"
  exit 1
fi

# 2. Fetch JS-rendered HTML via Playwright
cat > "$TMP_JS" << JSEOF
import { chromium } from '${PLAYWRIGHT_PATH}';
import fs from 'fs';

const [url, outPath] = process.argv.slice(2);
const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();
await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
const html = await page.content();
fs.writeFileSync(outPath, html);
await browser.close();
JSEOF

node "$TMP_JS" "$URL" "$TMP_HTML"
rm -f "$TMP_JS"

if [ ! -s "$TMP_HTML" ]; then
  echo "ERROR: Playwright HTML extraction failed"
  rm -f "$TMP_HTML"
  exit 1
fi

# 2. Convert HTML → markdown + metadata via Defuddle
JSON=$(defuddle parse "$TMP_HTML" --json --markdown 2>/dev/null || true)
rm -f "$TMP_HTML"

if [ -z "$JSON" ]; then
  echo "ERROR: defuddle conversion failed"
  exit 1
fi

# 3. Extract metadata from JSON
TITLE=$(echo "$JSON" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); console.log(d.title||'')")
AUTHOR=$(echo "$JSON" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); console.log(d.author||'')")
DOMAIN=$(echo "$JSON" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); console.log(d.domain||'')" 2>/dev/null || echo "")
PUBLISHED=$(echo "$JSON" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); console.log(d.published||'')")
CONTENT=$(echo "$JSON" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); process.stdout.write(d.content||'')")

# If domain is empty, extract from URL
if [ -z "$DOMAIN" ]; then
  DOMAIN=$(echo "$URL" | sed 's|https\?://||' | sed 's|/.*||')
fi

# 4. Generate filename
if [ -z "$FILENAME" ]; then
  FILENAME=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | head -c 80)
  if [ -z "$FILENAME" ]; then
    FILENAME="clip-$(date +%Y%m%d%H%M%S)"
  fi
fi

OUTPUT_FILE="$SOURCES_DIR/$FILENAME.md"

# 5. Assemble frontmatter + body
cat > "$OUTPUT_FILE" << FRONTMATTER
---
title: "$TITLE"
source-type: $CATEGORY
source-url: "$URL"
author: "$AUTHOR"
domain: "$DOMAIN"
published: "$PUBLISHED"
ingested-date: $TODAY
---

$CONTENT
FRONTMATTER

echo "Saved: $OUTPUT_FILE"
echo "  title: $TITLE"
echo "  domain: $DOMAIN"
