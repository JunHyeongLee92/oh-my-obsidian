# Obsidian Vault

[English](README.md) · **한국어**

LLM이 유지하는 개인 지식 베이스. [oh-my-obsidian](https://github.com/JunHyeongLee92/oh-my-obsidian) 플러그인으로 운영되며, 이 저장소는 **데이터만** 담고 규칙·스크립트·스키마는 플러그인에 있다.

## 레이아웃

```
<vault>/
├── wiki/                      # LLM이 관리하는 상호 연결된 위키 (_sources/에서 파생)
│   ├── index.md               #   전체 색인 (카테고리별 페이지 목록)
│   ├── log.md                 #   변경 이력 (append-only: ingest/create/update/delete/lint/promoted/analyze)
│   ├── entities/              #   사람·도구·서비스·제품·조직
│   ├── concepts/              #   패턴·방법론·기술 아이디어
│   ├── guides/                #   How-to 가이드
│   ├── summaries/             #   소스 1건당 요약 1건 (ingest 산출물)
│   └── digests/               #   주간 재가공 (월요일 03:30 cron)
├── projects/                  # 사용자·LLM 협업 작업 공간 (연결된 repo 별)
│   └── <name>/
│       ├── index.md           #   프로젝트 개요·현재 상태 (1페이지 허브) — /omo-project-add 시 생성
│       ├── worklog/           #   일자별 작업 기록 — /omo-project-add 시 생성
│       ├── decisions/         #   ADR 형식 의사결정 레코드 — /omo-project-add 시 생성
│       ├── docs/              #   정적 이해 문서 (architecture.md, usage.md) — /omo-project-analyze 실행 시 생성
│       └── jira/              #   (선택) Jira 티켓 기록 — 사용자가 수동 생성
├── _sources/                  # 외부 원본 (한 번 저장 후 불변)
│   ├── articles/              #   웹 아티클
│   ├── papers/                #   논문
│   ├── conversations/         #   대화·회의록
│   ├── assets/                #   이미지·첨부
│   └── misc/                  #   기타
├── _ops/
│   ├── lint-reports/          # lint 출력 (머신별 latest-<hostname>.md만 git 추적)
│   └── templates/             # Obsidian Templater 템플릿 10종 (수동 페이지 생성)
├── .obsidian/                 # Obsidian 설정 (templates.json이 _ops/templates를 가리킴)
├── README.md                  # 이 문서
└── .gitignore
```

**볼트 외부 SSOT**: `~/.config/oh-my-obsidian/config.json` — `vaultPath`, `pluginRoot`, `syncMode` 저장. `/omo-init`이 최초 1회 생성하며 모든 스킬·스크립트가 이 파일을 통해 경로를 해석한다.

**페이지 유형 규칙**: 각 폴더의 페이지는 정해진 필수 섹션·프론트매터 스키마를 따른다. 상세는 플러그인 `schema/page-types.md`, `schema/frontmatter-spec.md` 참조.

## 쓰는 법

- `/omo-ingest <URL>` — URL을 볼트에 추가 (원본 → `_sources/`, 구조화 → `wiki/entities`·`wiki/concepts`·`wiki/summaries`)
  - 예: `/omo-ingest https://github.com/anthropics/claude-code`
  - 자연어: "이 URL 위키에 추가해줘 https://..."

- `/omo-query <keyword>` — 볼트에서 검색, 답변 재사용 가치 있으면 새 페이지로 자동 승격
  - 예: `/omo-query LangGraph 에이전트 패턴`
  - 자연어: "위키에서 LangGraph 찾아줘"

- `/omo-project-add` — 현재 git 프로젝트를 볼트 `projects/<name>/`에 연결 (프로젝트 CLAUDE.md에 project-name도 기록)
  - 예: 프로젝트 루트에서 `/omo-project-add`
  - 자연어: "이 프로젝트 위키에 연동해줘"

- `/omo-project-analyze` — repo를 분석해 `projects/<name>/docs/architecture.md`·`usage.md` 생성 (이후 세션에서 재접근 시 빠른 re-ground)
  - 예: 프로젝트 루트에서 `/omo-project-analyze`
  - 자연어: "이 프로젝트 분석해서 문서 만들어줘"

- `/omo-project-update` — `wiki-staleness-check` 훅 경고 원샷 해결 (현재 상태 재작성 + `updated` 갱신 + 필요 시 worklog/ADR 초안)
  - 예: `/omo-project-update <name>` (인자 없으면 현재 cwd 기준 해석)
  - 자연어: "프로젝트 위키 최신화해줘"

- `/omo-study <URL|주제>` — 볼트 맥락 기반 단계별 학습 (객관식 step check 포함)
  - 예: `/omo-study differential privacy`
  - 자연어: "이거 가르쳐줘 https://..."

- `/omo-lint` — 스키마·링크·프론트매터 일관성 점검, CRITICAL 승낙 후 수정
  - 예: `/omo-lint` (인자 없음)

- `/omo-digest` — 주간 재가공 (기본 cron: 월요일 03:30에 자동 생성)
  - 수동 즉시 생성도 가능

## 수동 페이지 생성 (Obsidian)

Obsidian에서 `Ctrl/Cmd+P` → "Insert template" → `_ops/templates/`의 10종 중 선택:

`wiki-entity` · `wiki-concept` · `wiki-guide` · `wiki-summary` · `wiki-project` · `wiki-decision` · `wiki-digest` · `wiki-jira` · `work-log-entry` · `source-ingest`

스킬(`/omo-ingest` 등)이 자동 생성할 때도 같은 스키마를 따르므로, 수동·자동 산출물이 일관된 구조를 갖는다.

## 자동화

`/omo-init` 실행 시 등록되는 cron (`# OMO-CRON:<name>` 태그로 식별):

- **매일 03:00** — `lint.sh` (스키마 위반 검출, 리포트만 생성)
- **매일 03:15** — `qmd-update.sh` (Obsidian 인덱스 갱신)
- **월요일 03:30** — `weekly-digest.sh` (Claude CLI 호출로 주간 재가공)

`git-sync`는 원격·인증 준비가 필요하므로 자동 등록 대상이 **아니다** (아래 Tip 참조).

## 훅 (자동 경고)

- **wiki-staleness-check** — git 프로젝트에서 `feat/fix/refactor/perf` 커밋 시, 연결된 `projects/<name>/index.md`의 `updated` 필드와 비교해 오래됐으면 `[wiki-check] ⚠️ wiki stale: ...` 경고를 표시. 경고를 받으면 `/omo-project-update <name>`로 **한 번에 해결** (최근 커밋 읽어 현재 상태 재작성 + `updated` 갱신 + 필요 시 worklog/ADR 초안까지).
- 프로젝트를 아직 볼트에 연결하지 않은 상태라면 경고가 아닌 `/omo-project-add` 안내 메시지가 뜸.

## Tip — Git 자동 백업 (선택)

이 볼트를 git 원격 저장소(GitHub 등)에 연결하면, 플러그인의 `git-sync.sh`를 cron에 등록해 주기적으로 자동 백업할 수 있다. 멀티 머신에서 같은 볼트를 공유하려 할 때 특히 유용.

```bash
# 1) 볼트에 원격 연결 (한 번)
cd <vault>
git init
git remote add origin git@github.com:<user>/<vault-repo>.git
git add -A && git commit -m "initial vault"
git push -u origin main

# 2) SSH 키 준비 (~/.ssh/id_ed25519 또는 id_rsa)

# 3) 크론 등록 (OMO-CRON 태그 붙이면 uninstall-cron이 인식)
#    플러그인 경로는 Claude Code 설치 환경마다 다르므로 config에서 해석
PLUGIN_ROOT=$(jq -r .pluginRoot ~/.config/oh-my-obsidian/config.json)
(crontab -l 2>/dev/null; echo "0 */4 * * * bash $PLUGIN_ROOT/scripts/git-sync.sh >> $HOME/.local/state/oh-my-obsidian/git-sync.log 2>&1 # OMO-CRON:sync") | crontab -
```

원격 연결이나 SSH 설정 안 하면 sync는 실패만 반복하므로, 자동 등록 대상에서 제외돼 있다.
