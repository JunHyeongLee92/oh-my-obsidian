# Changelog

All notable changes to oh-my-obsidian are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
