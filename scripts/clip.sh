#!/usr/bin/env bash
set -euo pipefail

# clip.sh — extract the original content from a URL and save it under <vault>/_sources/
# Render with Playwright (headless browser) → convert to markdown with Defuddle (no AI processing).
#
# Exit codes:
#   0  success — _sources/<category>/<filename>.md written
#   1  hard error — Playwright failed, missing tools, or other unrecoverable issue
#   2  Defuddle could not extract content but Playwright HTML is preserved.
#      Stdout includes FALLBACK_HTML=<path>, FALLBACK_URL=<url>,
#      FALLBACK_CATEGORY=<cat>, and optionally FALLBACK_FILENAME=<name>.
#      The calling skill is expected to perform LLM-based extraction from
#      the preserved HTML and write _sources/ itself.

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

# 2. Fetch JS-rendered HTML via Playwright.
#
# Hardening for sites that detect headless Chrome (anti-bot, Next.js error
# boundaries that crash on suspicious environments, etc.):
#   - Real Chrome user-agent (Playwright's default UA contains "HeadlessChrome")
#   - Desktop viewport so we don't trigger mobile-only code paths
#   - en-US locale + Accept-Language header
#   - Hide navigator.webdriver via init script (most common automation signal)
#   - --disable-blink-features=AutomationControlled to drop the Chrome flag
#   - waitUntil: 'load' + bounded networkidle follow-up so pages with long-lived
#     analytics/heartbeat connections don't hit the 30s hard timeout
cat > "$TMP_JS" << JSEOF
import { chromium } from '${PLAYWRIGHT_PATH}';
import fs from 'fs';

const [url, outPath] = process.argv.slice(2);
const browser = await chromium.launch({
  headless: true,
  args: ['--disable-blink-features=AutomationControlled'],
});
const context = await browser.newContext({
  userAgent: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
  viewport: { width: 1920, height: 1080 },
  locale: 'en-US',
  timezoneId: 'America/Los_Angeles',
  extraHTTPHeaders: { 'Accept-Language': 'en-US,en;q=0.9' },
});
await context.addInitScript(() => {
  Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
});
const page = await context.newPage();
await page.goto(url, { waitUntil: 'load', timeout: 30000 });
// Give hydration a chance to settle, but don't hang on long-lived connections
await page.waitForLoadState('networkidle', { timeout: 10000 }).catch(() => {});
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

# Defuddle is happy only when it returns JSON AND the content field looks like
# real article body. JS-heavy marketing pages can produce three failure modes:
#   (a) no JSON at all                              → empty $JSON
#   (b) JSON with empty content                     → length 0
#   (c) JSON with content that is just a title /    → length below threshold
#       site name fragment (Defuddle "succeeds"
#       on metadata but never finds the body)
# Treat all three as fallback-eligible. The 200-char floor is well below any
# real article (typical clipped articles in this vault are 5KB+) but well
# above metadata-only fragments.
DEFUDDLE_MIN_CONTENT_CHARS=${DEFUDDLE_MIN_CONTENT_CHARS:-200}
DEFUDDLE_OK=0
if [ -n "$JSON" ]; then
  CONTENT_LEN=$(echo "$JSON" | node -e "
    try {
      const d = JSON.parse(require('fs').readFileSync(0, 'utf8'));
      process.stdout.write(String(((d.content || '').trim()).length));
    } catch (_) { process.stdout.write('0'); }
  " 2>/dev/null || echo "0")
  if [ "${CONTENT_LEN:-0}" -ge "$DEFUDDLE_MIN_CONTENT_CHARS" ]; then
    DEFUDDLE_OK=1
  fi
fi

if [ "$DEFUDDLE_OK" = "0" ]; then
  echo "WARN: defuddle could not extract structured content"
  echo "FALLBACK_HTML=$TMP_HTML"
  echo "FALLBACK_URL=$URL"
  echo "FALLBACK_CATEGORY=$CATEGORY"
  if [ -n "$FILENAME" ]; then
    echo "FALLBACK_FILENAME=$FILENAME"
  fi
  cat <<EOF

The rendered HTML is preserved at the path above. The calling skill should:
  1. Read the HTML file
  2. Extract title / author / published / body via LLM
  3. Write _sources/$CATEGORY/<slug>.md with the standard frontmatter
  4. Remove the temporary HTML file
EOF
  exit 2
fi

rm -f "$TMP_HTML"

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
