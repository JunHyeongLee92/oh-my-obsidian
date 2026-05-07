# Changelog

All notable changes to oh-my-obsidian are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.6] - 2026-05-07

### Added

- PDF ingest path. `scripts/clip.sh` now detects PDF inputs (local file with `%PDF` magic bytes, or `https://...pdf` URL) and dispatches to the new `scripts/lib/pdf-clip.sh` module, which uses `pdftotext` (poppler-utils) for body extraction and `pdfinfo` for metadata (title, author, CreationDate, page count). Local PDFs are read in place; remote PDFs are downloaded to `/tmp` first and cleaned up after extraction. Layout mode is configurable via `OMO_PDF_LAYOUT=true|false` (default `true` preserves columns/tables). Scanned/image-only PDFs return exit 1 with an OCR hint.
- `scripts/clip.sh` first argument now accepts a **local file path** in addition to a URL. The previous URL-only contract is preserved for callers; this is a strict superset.
- `omo-ingest` SKILL describes the PDF branch alongside the YouTube and web/Defuddle paths and recommends `papers` for academic PDFs and `articles` for reports/whitepapers.

## [0.0.5] - 2026-05-07

### Added

- YouTube ingest path. `scripts/clip.sh` now detects `youtube.com` / `youtu.be` / `m.youtube.com` URLs and dispatches to the new `scripts/lib/youtube-clip.sh` module, which uses yt-dlp to download manual subs (preferred) or auto-captions, strips VTT rolling-window duplication, and writes a normal `_sources/<category>/<slug>.md` with the standard frontmatter shape. Subtitle language preference is configurable via `OMO_YT_SUB_LANG` (default `ko,en`). The exit-code contract is unchanged for callers; YouTube uses only exit 0 (success) and 1 (hard error) because there is no Defuddle-style fallback when the spoken content lives in audio rather than HTML. Requires yt-dlp on `PATH` or at `~/.local/bin/yt-dlp` — install via `mkdir -p ~/.local/bin && curl -L -o ~/.local/bin/yt-dlp https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp && chmod +x ~/.local/bin/yt-dlp`.
- `omo-ingest` SKILL describes the YouTube branch alongside the existing web/Defuddle path and recommends `misc` as the category for video transcripts.

## [0.0.4] - 2026-05-07

### Added

- Codex plugin surface via `.codex-plugin/plugin.json` and a repo-local `.agents/plugins/marketplace.json`.
- Codex local-development instructions in README files and `.codex-plugin/README.md`.
- Harness-compatibility notes for interactive skills when Codex does not expose Claude Code's `AskUserQuestion` tool.
- LLM fallback path in `scripts/clip.sh` for pages where Defuddle cannot identify the article body (common on JS-heavy marketing pages with weak semantic markup). On such failures clip.sh now preserves the Playwright-rendered HTML, prints `FALLBACK_HTML=` / `FALLBACK_URL=` / `FALLBACK_CATEGORY=` (and optional `FALLBACK_FILENAME=`) to stdout, and exits with code 2. `omo-ingest` SKILL has a new "Exit 2 — LLM fallback" branch that reads the preserved HTML, extracts title / author / published / body via LLM, writes `_sources/<category>/<slug>.md` with the standard frontmatter, and removes the temporary HTML. Fresh re-fetches are deliberately avoided so the rendered DOM is never thrown away.

### Changed

- `scripts/weekly-digest.sh` can now run through either Claude Code (`OMO_DIGEST_AGENT=claude`, default) or Codex (`OMO_DIGEST_AGENT=codex`).
- `scripts/lib/config.sh` now falls back to the current plugin checkout (or `OMO_PLUGIN_ROOT`) when `pluginRoot` is omitted from config.
- `omo-init` now resolves a local Codex marketplace checkout before falling back to Claude Code marketplace paths.
- `scripts/clip.sh` exit-code contract is now `{0=ok, 1=hard error, 2=Defuddle-failed-but-Playwright-rendered}` (previously `{0=ok, 1=any failure}`). Existing callers that only check exit 0 are unaffected; callers that branch on non-zero should distinguish 2 from 1 to take advantage of the LLM fallback.
- `scripts/clip.sh` Playwright stage hardened against headless detection: real Chrome user-agent (default UA contains "HeadlessChrome"), 1920×1080 desktop viewport, en-US locale + `Accept-Language` header, `--disable-blink-features=AutomationControlled`, and `navigator.webdriver` hidden via init script. Fixes pages such as `anthropic.com/news/*` that previously rendered to a Next.js `Application error: a client-side exception has occurred` shell because the site's runtime detected an automation environment and aborted hydration.
- `scripts/clip.sh` page-load strategy switched from `waitUntil: 'networkidle'` (which hangs the full 30s timeout on SPAs with long-lived analytics/heartbeat connections) to `waitUntil: 'load'` followed by a bounded 10s `networkidle` follow-up. Hydration still gets time to settle without the hard timeout.
- `scripts/clip.sh` adds a `DEFUDDLE_MIN_CONTENT_CHARS` env var (default 200) to control the threshold below which Defuddle output is treated as fallback-eligible. Catches "Defuddle returned JSON with only the title fragment as content" false positives.
- `schema/wiki-rules.md` § "1. Ingest" now documents the LLM fallback branch alongside the Defuddle happy path.

## [0.0.3] - 2026-04-24

### Fixed

- `.claude-plugin/marketplace.json` 의 `plugins[0].version` 이 `0.0.1` 에 고정되어 있어, `plugin.json` 만 bump해도 `/plugin` UI가 구버전(0.0.1)을 표시하던 문제. marketplace.json과 plugin.json 버전을 함께 `0.0.3` 으로 동기화.

## [0.0.2] - 2026-04-24

### Fixed

- `schema/mermaid-style.md`에 Character escaping 섹션 추가. `sequenceDiagram` 메시지 안에서 `<...>` / `&lt;...&gt;` 모두 `Parse error ... got 'NEWLINE'`을 유발하므로 `[placeholder]` 표기를 사용하도록 스킬 계약 명시. `omo-project-analyze`가 생성하는 `usage.md`의 sequence 다이어그램 렌더링 실패 재발 방지.

### Changed

- 릴리스 방식을 additive commit + version bump + tag push로 전환. v0.0.1 클린 슬레이트(DEC-004)는 최초 공개 1회 예외로 박제; 이후 `main` force-push 지양.

## [0.0.1] - 2026-04-24

Initial release.
