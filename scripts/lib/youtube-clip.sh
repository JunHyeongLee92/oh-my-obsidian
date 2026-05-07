#!/usr/bin/env bash
# youtube-clip.sh — YouTube transcript ingest path for clip.sh
#
# Sourced by scripts/clip.sh when the URL is a YouTube link. The Playwright +
# Defuddle pipeline can render the YouTube page but never reaches the actual
# spoken content; yt-dlp is the right tool for that. We extract subtitles
# (manual preferred, auto-caption fallback), strip rolling-window duplication
# from the VTT format, and write a regular _sources/<category>/<slug>.md so
# downstream omo-ingest behaves the same as for any other source.
#
# Public functions:
#   omo_is_youtube_url <url>            — return 0 if URL is YouTube
#   omo_resolve_yt_dlp                  — echo path to yt-dlp or non-zero
#   omo_clip_youtube <url> <vault_root> <category> [<filename>]
#                                       — full clip flow, returns 0 on success
#
# Env:
#   OMO_YT_SUB_LANG    — comma-separated subtitle language preference
#                        (default: "ko,en"). Manual subs are tried before
#                        auto-generated.

omo_is_youtube_url() {
  local url="$1"
  [[ "$url" =~ ^https?://(www\.|m\.)?(youtube\.com|youtu\.be)/ ]]
}

omo_resolve_yt_dlp() {
  local p
  p="$(command -v yt-dlp 2>/dev/null || true)"
  if [ -n "$p" ]; then
    printf '%s' "$p"
    return 0
  fi
  if [ -x "$HOME/.local/bin/yt-dlp" ]; then
    printf '%s' "$HOME/.local/bin/yt-dlp"
    return 0
  fi
  return 1
}

# Convert VTT (with rolling-window auto-caption duplicates) to a flat
# transcript. Strategy: for each cue, keep only lines that contain word-level
# timing tags (= the "newly added" line); strip the tags; concatenate with
# spaces.
_omo_yt_vtt_to_text() {
  local vtt_path="$1"
  python3 - "$vtt_path" <<'PYEOF'
import re, sys
with open(sys.argv[1], "r") as f:
    vtt = f.read()
blocks = re.split(r"\n\n+", vtt)
out = []
for b in blocks:
    lines = b.strip().split("\n")
    if not lines or lines[0].startswith("WEBVTT"):
        continue
    text_lines = [ln for ln in lines if "-->" not in ln]
    for ln in text_lines:
        if "<" in ln and ">" in ln:
            cleaned = re.sub(r"<[^>]+>", "", ln).strip()
            if cleaned:
                out.append(cleaned)
text = " ".join(out)
text = re.sub(r"\s+", " ", text).strip()
sys.stdout.write(text)
PYEOF
}

omo_clip_youtube() {
  local url="$1"
  local vault_root="$2"
  local category="$3"
  local filename="${4:-}"
  local today
  today=$(date +%Y-%m-%d)
  local sources_dir="$vault_root/_sources/$category"
  mkdir -p "$sources_dir"

  echo "Extracting (YouTube): $url"

  local yt_dlp
  yt_dlp="$(omo_resolve_yt_dlp)" || {
    echo "ERROR: yt-dlp not found." >&2
    echo "Install: mkdir -p ~/.local/bin && curl -L -o ~/.local/bin/yt-dlp https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp && chmod +x ~/.local/bin/yt-dlp" >&2
    return 1
  }

  # 1. Probe metadata. yt-dlp's --print does not interpret %0A as a newline,
  # so use one --print per field — each emits on its own line.
  local meta
  meta=$("$yt_dlp" --skip-download --no-playlist --no-warnings \
    --print "%(title)s" \
    --print "%(uploader)s" \
    --print "%(upload_date)s" \
    --print "%(duration_string)s" \
    --print "%(id)s" \
    "$url" 2>/dev/null) || {
    echo "ERROR: yt-dlp metadata fetch failed" >&2
    return 1
  }
  local title uploader upload_date duration video_id
  title=$(echo "$meta" | sed -n '1p')
  uploader=$(echo "$meta" | sed -n '2p')
  upload_date=$(echo "$meta" | sed -n '3p')
  duration=$(echo "$meta" | sed -n '4p')
  video_id=$(echo "$meta" | sed -n '5p')

  if [ -z "$video_id" ] || [ -z "$title" ]; then
    echo "ERROR: could not extract YouTube metadata" >&2
    return 1
  fi

  local published=""
  if [[ "$upload_date" =~ ^[0-9]{8}$ ]]; then
    published="${upload_date:0:4}-${upload_date:4:2}-${upload_date:6:2}"
  fi

  # 2. Subtitle download (manual + auto), preferred langs from OMO_YT_SUB_LANG
  local sub_lang="${OMO_YT_SUB_LANG:-ko,en}"
  local tmp_dir="/tmp/omo-yt-$$-$(date +%s)"
  mkdir -p "$tmp_dir"

  # yt-dlp returns non-zero if ANY requested language fails (e.g. YouTube rate-
  # limiting auto-translated languages with HTTP 429), even when the primary
  # language succeeded. So ignore the exit code and judge success by whether
  # a usable VTT actually landed on disk in the lang-preference loop below.
  "$yt_dlp" --skip-download --no-playlist --no-warnings --ignore-errors \
    --write-subs --write-auto-subs \
    --sub-lang "$sub_lang" --sub-format vtt \
    -o "$tmp_dir/%(id)s.%(ext)s" \
    "$url" >/dev/null 2>&1 || true

  # Pick the first available VTT in the user's preferred lang order
  local vtt_file=""
  IFS=',' read -ra LANGS <<< "$sub_lang"
  for lang in "${LANGS[@]}"; do
    lang=$(echo "$lang" | xargs)
    [ -z "$lang" ] && continue
    if [ -f "$tmp_dir/$video_id.$lang.vtt" ]; then
      vtt_file="$tmp_dir/$video_id.$lang.vtt"
      break
    fi
  done

  if [ -z "$vtt_file" ]; then
    echo "ERROR: no usable subtitle in langs: $sub_lang" >&2
    echo "  Try OMO_YT_SUB_LANG=<lang>,<lang>,... or check yt-dlp --list-subs $url" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  echo "  Using subtitle: $(basename "$vtt_file")"

  # 3. VTT → flat transcript
  local transcript
  transcript=$(_omo_yt_vtt_to_text "$vtt_file") || {
    echo "ERROR: VTT-to-text conversion failed" >&2
    rm -rf "$tmp_dir"
    return 1
  }
  rm -rf "$tmp_dir"

  if [ -z "$transcript" ] || [ "${#transcript}" -lt 200 ]; then
    echo "ERROR: extracted transcript empty or below 200 chars (got ${#transcript})" >&2
    return 1
  fi

  # 4. Slug. The naive title→kebab-case strips non-ASCII, which collapses CJK
  # titles into a meaningless residue (e.g. "오늘, 클로드가 PPT를 죽였습니다."
  # → "ppt"). When the result is empty OR shorter than 8 chars, fall back to
  # the YouTube video ID so collisions are impossible.
  if [ -z "$filename" ]; then
    filename=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | head -c 80)
    if [ -z "$filename" ] || [ "${#filename}" -lt 8 ]; then
      filename="youtube-$video_id"
    fi
  fi

  local output_file="$sources_dir/$filename.md"
  local domain="youtube.com"

  # 5. Write _sources file (frontmatter + transcript with provenance comment)
  cat > "$output_file" << FM
---
title: "$title"
source-type: $category
source-url: "$url"
author: "$uploader"
domain: "$domain"
published: "$published"
ingested-date: $today
---

<!-- Source: yt-dlp subtitle (manual or auto-generated, lang chosen at clip time), rolling-window deduplicated. May contain proper-noun mistranscriptions. -->

$transcript
FM

  echo "Saved: $output_file"
  echo "  title: $title"
  echo "  channel: $uploader"
  echo "  published: $published"
  echo "  duration: $duration"
  return 0
}
