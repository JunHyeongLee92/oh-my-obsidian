#!/usr/bin/env bash
# pdf-clip.sh — PDF ingest path for clip.sh
#
# Sourced by scripts/clip.sh when the input looks like a PDF — either an
# https://...pdf URL or a local filesystem path whose first 4 bytes are %PDF.
# The Playwright + Defuddle path can render a PDF URL to a viewer page but
# never extracts the body; pdftotext (poppler-utils) is the right tool.
# Local PDFs are read in place; remote PDFs are downloaded to /tmp first and
# cleaned up after extraction.
#
# Public functions:
#   omo_is_pdf_input <input>            — return 0 if URL ending in .pdf or
#                                         existing local file with PDF magic
#   omo_clip_pdf <input> <vault_root> <category> [<filename>]
#                                       — full clip flow, returns 0 on success
#
# Env:
#   OMO_PDF_LAYOUT     — pdftotext layout mode (default: "true").
#                        true  = pdftotext -layout (preserve columns/tables)
#                        false = pdftotext        (single-column flow)

omo_is_pdf_input() {
  local input="$1"
  # URL form: https://...pdf or http://...pdf with optional ?query / #frag
  if [[ "$input" =~ ^https?://.*\.pdf(\?|#|$) ]]; then
    return 0
  fi
  # Local path form: expand ~, accept absolute or ./ relative
  local resolved="${input/#\~/$HOME}"
  if [[ -f "$resolved" ]]; then
    # Verify PDF magic bytes
    local magic
    magic=$(head -c 4 "$resolved" 2>/dev/null)
    [[ "$magic" == "%PDF" ]]
    return $?
  fi
  return 1
}

omo_clip_pdf() {
  local input="$1"
  local vault_root="$2"
  local category="$3"
  local filename="${4:-}"
  local today
  today=$(date +%Y-%m-%d)
  local sources_dir="$vault_root/_sources/$category"
  mkdir -p "$sources_dir"

  echo "Extracting (PDF): $input"

  if ! command -v pdftotext >/dev/null 2>&1; then
    echo "ERROR: pdftotext not found. Install poppler-utils:" >&2
    echo "  apt:  sudo apt install poppler-utils" >&2
    echo "  brew: brew install poppler" >&2
    return 1
  fi

  # Resolve input → local pdf_path. Remote URLs are downloaded to /tmp. Track
  # an "original_basename" derived from the human-meaningful input (URL path
  # or local filename) so it can be used as a title fallback when pdfinfo's
  # Title field is empty — without leaking the synthetic /tmp download name.
  local pdf_path source_url cleanup_pdf="" original_basename
  if [[ "$input" =~ ^https?:// ]]; then
    source_url="$input"
    pdf_path="/tmp/omo-pdf-$$-$(date +%s).pdf"
    if ! curl -L -fsS -o "$pdf_path" "$input"; then
      echo "ERROR: failed to download PDF from $input" >&2
      rm -f "$pdf_path"
      return 1
    fi
    cleanup_pdf="$pdf_path"
    # Derive original basename from URL path: strip query/fragment, strip .pdf
    local url_path="${input%%\?*}"
    url_path="${url_path%%#*}"
    original_basename=$(basename "$url_path" .pdf)
  else
    pdf_path="${input/#\~/$HOME}"
    # Resolve to absolute for the source-url field
    if [[ "$pdf_path" != /* ]]; then
      pdf_path="$(cd "$(dirname "$pdf_path")" && pwd)/$(basename "$pdf_path")"
    fi
    source_url="file://$pdf_path"
    original_basename=$(basename "$pdf_path" .pdf)
  fi

  if [ ! -s "$pdf_path" ]; then
    echo "ERROR: PDF file is empty or missing: $pdf_path" >&2
    [ -n "$cleanup_pdf" ] && rm -f "$cleanup_pdf"
    return 1
  fi

  local magic
  magic=$(head -c 4 "$pdf_path" 2>/dev/null)
  if [ "$magic" != "%PDF" ]; then
    echo "ERROR: file is not a PDF (magic bytes: '$magic')" >&2
    [ -n "$cleanup_pdf" ] && rm -f "$cleanup_pdf"
    return 1
  fi

  # 1. Metadata (best-effort — pdfinfo is optional)
  local title="" author="" published="" page_count=""
  if command -v pdfinfo >/dev/null 2>&1; then
    local info
    info=$(pdfinfo "$pdf_path" 2>/dev/null)
    title=$(echo "$info" | sed -n 's/^Title:[[:space:]]*//p' | head -1)
    author=$(echo "$info" | sed -n 's/^Author:[[:space:]]*//p' | head -1)
    page_count=$(echo "$info" | sed -n 's/^Pages:[[:space:]]*//p' | head -1)

    # Try CreationDate. Two common formats from pdfinfo:
    #   "D:20260414123000+09'00'"  (raw PDF date string)
    #   "Mon Apr 14 12:30:00 2026 KST"  (formatted)
    local raw_date
    raw_date=$(echo "$info" | sed -n 's/^CreationDate:[[:space:]]*//p' | head -1)
    if [[ "$raw_date" =~ ^D:([0-9]{4})([0-9]{2})([0-9]{2}) ]]; then
      published="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]}"
    elif [[ "$raw_date" =~ ([A-Za-z]{3})[[:space:]]+([0-9]+)[[:space:]]+[0-9:]+[[:space:]]+([0-9]{4}) ]]; then
      local mname="${BASH_REMATCH[1]}"
      local day month year
      day=$(printf '%02d' "${BASH_REMATCH[2]}")
      year="${BASH_REMATCH[3]}"
      case "$mname" in
        Jan) month="01" ;; Feb) month="02" ;; Mar) month="03" ;; Apr) month="04" ;;
        May) month="05" ;; Jun) month="06" ;; Jul) month="07" ;; Aug) month="08" ;;
        Sep) month="09" ;; Oct) month="10" ;; Nov) month="11" ;; Dec) month="12" ;;
        *) month="" ;;
      esac
      [ -n "$month" ] && published="$year-$month-$day"
    fi
  fi

  # Fallback title: original basename (URL path basename or local filename),
  # never the synthetic /tmp download path.
  if [ -z "$title" ]; then
    title="$original_basename"
  fi

  # 2. Extract text via pdftotext
  local pdf_layout="${OMO_PDF_LAYOUT:-true}"
  local body
  if [ "$pdf_layout" = "true" ]; then
    body=$(pdftotext -layout "$pdf_path" - 2>/dev/null)
  else
    body=$(pdftotext "$pdf_path" - 2>/dev/null)
  fi

  [ -n "$cleanup_pdf" ] && rm -f "$cleanup_pdf"

  if [ -z "$body" ] || [ "${#body}" -lt 200 ]; then
    echo "ERROR: pdftotext produced empty or too-short output (${#body} chars)" >&2
    echo "  Likely a scanned/image-only PDF — needs OCR (tesseract or similar)" >&2
    return 1
  fi

  # 3. Slug. Naive title→kebab-case strips non-ASCII; fall back to a
  # timestamp-based name when the result is empty or too short to be useful
  # (CJK titles collapse to a few residual letters).
  if [ -z "$filename" ]; then
    filename=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | head -c 80)
    if [ -z "$filename" ] || [ "${#filename}" -lt 8 ]; then
      filename="pdf-$(date +%Y%m%d-%H%M%S)"
    fi
  fi

  local output_file="$sources_dir/$filename.md"
  local domain
  if [[ "$input" =~ ^https?://([^/]+) ]]; then
    domain="${BASH_REMATCH[1]}"
  else
    domain="local"
  fi

  # 4. Write _sources file with provenance comment
  cat > "$output_file" << FM
---
title: "$title"
source-type: $category
source-url: "$source_url"
author: "$author"
domain: "$domain"
published: "$published"
ingested-date: $today
---

<!-- Source: pdftotext extraction (layout=$pdf_layout, pages=${page_count:-unknown}). May contain artifacts from columns, tables, or PDF positioning. Override layout via OMO_PDF_LAYOUT=true|false. -->

$body
FM

  echo "Saved: $output_file"
  echo "  title: $title"
  echo "  author: ${author:-(none)}"
  echo "  pages: ${page_count:-unknown}"
  echo "  published: ${published:-(none)}"
  return 0
}
