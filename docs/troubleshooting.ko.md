# Troubleshooting

[English](troubleshooting.md) · **한국어**

설치·런타임 이슈를 **증상 / 원인 / 해결** 구조로 정리. 여기에 없는 항목은 [GitHub Issue](https://github.com/JunHyeongLee92/oh-my-obsidian/issues)에 올려주세요.

## 설치

### `omo_require_node` 또는 "Node.js 20+ is required" 오류

**증상**: 스킬 호출마다 `ERROR: Node.js 20+ is required.` 출력.

**원인**: `scripts/lib/config.sh`가 JSON 파싱에 Node.js를 사용. 시스템 `node`가 없거나 버전이 낮음.

**해결**:

```bash
node --version   # v20+ 확인
# 없으면 nvm / mise / homebrew / apt로 설치
nvm install 20 && nvm use 20
# 또는
brew install node
```

설치 후 cron이 같은 PATH를 보도록 `crontab -e` 최상단에 `PATH=` 라인 추가를 고려 (특히 nvm 사용 시).

### `/omo-init` 후 config 파일 없음

**증상**: `cat ~/.config/oh-my-obsidian/config.json` → `No such file or directory`.

**원인**: `/omo-init`이 에러로 조기 종료했거나 `$XDG_CONFIG_HOME`이 비표준 경로로 설정됨.

**해결**:

```bash
# XDG override 확인
echo ${XDG_CONFIG_HOME:-$HOME/.config}

# 없으면 재실행
/omo-init <vault-path>
```

여전히 생성 안 되면 vault 경로 권한 확인 (`ls -ld <vault-path>`).

### `/plugin install`이 "already installed"라는데 내용이 옛 버전

**증상**: `/plugin install oh-my-obsidian`이 "already installed"를 출력하지만 캐시된 스킬·훅·스크립트가 이전 릴리스처럼 동작.

**원인**: Claude Code가 플러그인을 `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`에 버전 태그 기준으로 캐싱. 버전 bump 없이 릴리스하거나 같은 버전 위에서 로컬 iterate하면 캐시가 갱신되지 않음.

**해결**: stale 캐시 디렉토리를 지우고 재설치.

```bash
rm -rf ~/.claude/plugins/cache/oh-my-obsidian/oh-my-obsidian/<version>
/plugin install oh-my-obsidian
/reload-plugins
```

정상 릴리스에서는 `.claude-plugin/plugin.json:version` + `.claude-plugin/marketplace.json:version`을 새 SemVer로 bump — 버전이 다르면 Claude Code가 `/plugin install` 시 자동 리프레시.

### 플러그인 설치됐지만 스킬이 자연어에 매칭 안됨

**증상**: `/omo-ingest` 같은 슬래시 명령은 동작하는데 "이 URL 위키에 추가해줘" 같은 자연어가 매칭 안 됨.

**원인**: `/reload-plugins`를 건너뛰었거나 스킬 `description`에 자연어 trigger 예시가 없음.

**해결**:

```
/reload-plugins
```

로컬에서 스킬을 편집했다면 `description`에 자연어 trigger 예시를 포함시켜야 intent 매칭이 동작. `CONTRIBUTING.md` 참조.

## Cron

### Cron 미등록 / `crontab: command not found`

**증상**: `/omo-init` 출력이 cron 등록 실패를 표시.

**원인**:
- macOS: 최근 버전은 `cron`이 기본 비활성화 — `launchd` 필요.
- WSL: `cron` 서비스가 기본 실행 안 됨.

**해결**:

```bash
# WSL
sudo service cron start
# 부팅 자동 시작: /etc/wsl.conf에 [boot] command = service cron start 추가

# macOS (대안: 수작업 launchd plist 또는 cron 재활성화)
sudo launchctl load -F /System/Library/LaunchDaemons/com.vix.cron.plist
```

### Cron은 등록됐지만 lint / digest가 안 돌아감

**증상**: `crontab -l | grep OMO-CRON`에 항목은 있는데 `_ops/lint-reports/`에 리포트가 안 쌓임.

**원인**: cron의 `PATH`에 `node` 또는 `claude`가 없음 (사용자 shell PATH와 cron PATH가 다름).

**해결**: 먼저 로그 확인.

```bash
tail -50 <vault>/_ops/lint-reports/cron.log
tail -50 ~/.local/state/oh-my-obsidian/qmd-update.log
tail -50 ~/.local/state/oh-my-obsidian/weekly-digest.log
```

`command not found: node` / `claude` 메시지가 보이면 crontab 최상단에 PATH를 고정.

```
PATH=/home/<user>/.nvm/versions/node/v20.11.0/bin:/usr/local/bin:/usr/bin:/bin
```

### `omo-uninstall` 후에도 cron 남음

**증상**: 언인스톨 실행했는데 `crontab -l`에 OMO 라인이 여전히 있음.

**원인**: 해당 라인에 `# OMO-CRON:<name>` 태그가 없음 (보통 수동 추가한 경우).

**해결**: `crontab -e`로 수동 제거하거나 태그를 붙인 뒤 `uninstall-cron.sh`를 재실행.

## Lint

### `/omo-lint`가 CRITICAL을 보고하는데 자동 수정 prompt가 안 뜸

**증상**: lint 리포트에 CRITICAL 항목이 있는데 Claude가 fix 제안 없이 종료.

**원인**: 스킬의 AskUserQuestion 가드가 CRITICAL 존재 시에만 발동. 리포트 포맷이 malformed라 파싱 실패했을 가능성.

**해결**: 리포트 직접 확인.

```bash
cat <vault>/_ops/lint-reports/latest-$(hostname).md
```

비었거나 형식이 깨졌으면 `bash scripts/lint.sh`를 수동으로 돌려 stderr 확인.

### Lint가 새로 만든 페이지를 flag함

**증상**: 방금 생성한 페이지를 `missing-crossrefs` (INFO) 또는 `orphan-pages` (WARN)가 flag.

**원인**: 두 체크 모두 **다른 페이지의 역참조**와 **`index.md` 등록**에 의존. 막 만든 페이지는 아직 indexed 아님. 둘 다 CRITICAL 아님 — 설계상 advisory.

**해결**: `/omo-ingest` 또는 `/omo-query`의 자동 승격 경로를 쓰면 index 등록까지 자동 처리. 수동 생성했다면 `wiki/index.md`에 한 줄 추가. 전체 severity 표는 `schema/lint-rules.md` 참조 (CRITICAL / WARN / INFO).

## Ingest / Clip

### `/omo-ingest` 본문이 비어있음

**증상**: `_sources/articles/<name>.md`는 생성됐는데 본문이 거의 빔.

**원인**:
- 대상 사이트가 JS 렌더링 (정적 HTML 파서가 컨텐츠에 도달 못함).
- Paywall 또는 bot block.
- URL이 redirect loop.

**해결**:
- 브라우저 Reading Mode로 열어 수동으로 `_ops/templates/source-ingest.md`에 붙여넣기.
- 또는 `/omo-study <URL>` 사용 — 에이전트가 fetch + 해석.

### `/omo-ingest` 카테고리 잘못 분류

**증상**: 논문 URL이 `_sources/articles/`로 들어감.

**원인**: LLM이 제목과 본문만으로 카테고리를 추론. 모호할 때 fallback이 `articles`.

**해결**: 재실행 시 카테고리 명시.

```
/omo-ingest https://arxiv.org/abs/... category=papers
```

자연어로도 가능: "이 논문을 _sources/papers에 넣어줘".

## Weekly digest

### `weekly-digest.sh: claude not found in PATH`

**증상**: Cron 로그에 `ERROR: claude not found in PATH`와 exit 127.

**원인**: Cron이 Claude CLI를 못 찾음.

**해결**: crontab PATH 라인에 Claude CLI 경로 추가하거나 `CLAUDE_BIN` 설정.

```bash
# crontab -e 최상단
CLAUDE_BIN=/home/<user>/.local/bin/claude
```

### `omo-digest` 실행 시 "this week's digest already exists"

**증상**: 수동 호출이 "this week's digest already exists" 메시지로 종료.

**원인**: 설계상 digest는 주당 1회만 생성 (중복 방지).

**해결**: 강제 재생성이 필요하면 기존 파일 삭제 후 재실행.

```bash
rm <vault>/wiki/digests/$(date +%Y-W%V).md
/omo-digest
```

## Obsidian 연동

### Templater 템플릿이 Obsidian에서 안 보임

**증상**: `Ctrl/Cmd+P` → "Insert template" 목록에 `wiki-entity` 등이 안 뜸.

**원인**: `.obsidian/templates.json`이 더 이상 `_ops/templates/`를 가리키지 않음 (볼트 최초 오픈 시 Obsidian이 기본값으로 덮어썼을 수 있음).

**해결**:

```bash
cat <vault>/.obsidian/templates.json
# "folder": "_ops/templates" 확인
```

잘못 설정됐으면 Obsidian Settings → Templates → Template folder location을 `_ops/templates`로.

### 기본 Templates와 Templater 플러그인 충돌

**증상**: `<% tp.date.now() %>` 같은 Templater 구문이 리터럴 문자열로 삽입됨.

**원인**: core Templates 플러그인이 활성화 (Templater 변수를 이해 못함).

**해결**: Obsidian Settings → Core plugins → Templates **OFF**, Community plugins → Templater **ON**.

## 멀티 머신

### `/omo-lint` 리포트가 머신 간에 덮어쓰여짐

**증상**: 머신 A의 lint 리포트가 머신 B로 덮어쓰여짐.

**원인**: **설계상 발생하지 않아야 함** — lint 리포트는 `latest-<hostname>.md`로 per-host 저장. 실제 덮어쓰기가 일어나면 두 머신이 같은 `hostname`을 쓰는 것.

**해결**:

```bash
hostname
# 각 머신이 서로 다른 값인지 확인. 필요하면 /etc/hostname 변경.
```

### git-sync 충돌

**증상**: 여러 머신에서 편집 후 sync 시 git merge 충돌 발생.

**원인**: OMO는 자동 충돌 해결 전략이 없음 (설계상 사용자 수동 해결).

**해결**:

```bash
cd <vault>
git status
# 충돌 수동 해결
git add -A && git commit -m "resolve: merge conflicts from multi-machine sync"
git push
```

장기적으론 한 머신을 "편집기"로 지정 + sync 시각을 분산하는 게 안정적.

## Plugin hooks

### 커밋해도 staleness 경고가 안 뜸

**증상**: 프로젝트 코드 편집·커밋해도 위키 오래됨 경고가 안 나타남.

**원인**:
- `hooks/hooks.json`이 Claude Code에 등록 안 됨 (`/reload-plugins` 필요).
- Hook 스크립트 실행 권한 없음 (`chmod +x hooks/wiki-staleness-check.sh`).
- 프로젝트가 `/omo-project-add`로 볼트에 연결 안 됨 (`projects/<name>/` 없음).
- 시스템에 `jq` 미설치. Hook이 Claude Code tool-call JSON을 `jq`로 파싱 — 없으면 silent exit 0 (경고 없음).

**해결**:

```bash
ls -l hooks/wiki-staleness-check.sh  # 실행 비트 확인
command -v jq >/dev/null || { brew install jq; }   # 또는: apt-get install jq
/reload-plugins
# 프로젝트 루트에서
/omo-project-add
```

### v0.0.3+ 업그레이드 후 hook이 더 이상 안 뜸

**증상**: 플러그인 업데이트 후, 원래 경고가 뜨던 프로젝트에서도 staleness 경고가 안 나타남.

**원인**: v0.0.3에서 `CLAUDE.md`의 프로젝트 계약 키를 `프로젝트명:` (한글) → `project-name:` (영문)으로 rename. 이전 버전에서 연결된 프로젝트는 여전히 한글 키를 쓰는데 새 hook은 매칭 안 함.

**해결**: 연결된 각 프로젝트 루트에서

```bash
sed -i 's/- 프로젝트명: /- project-name: /' CLAUDE.md
```

또는 `/omo-project-add` 재실행 — AskUserQuestion으로 기존 라인을 새 키로 덮어쓰기.

## 프로젝트 스킬

### `/omo-project-update`가 "0 commits" 보고

**증상**: 최근 작업이 분명히 있는 프로젝트에 `/omo-project-update <name>` 호출했는데 "No meaningful commits since $UPDATED" 반환.

**원인**:
- 스킬이 커밋 메시지를 `^(feat|fix|refactor|perf)`로 필터 — `chore` / `docs` / `test` 커밋은 설계상 제외. 기능 변경을 `docs:`로 under-tag하면 invisible.
- Clean-slate 릴리스(orphan commit + force-push) 후에는 pre-wipe `feat`/`fix` 커밋이 `main`에서 unreachable.

**해결**:

1. Commit prefix 컨벤션 확인 — [CONTRIBUTING.md § Commit convention](../CONTRIBUTING.md#commit-convention) 참조. 새 스킬·기능 변경은 `feat(skills):`, `docs(skills):` 아님.
2. v0.0.3부터 스킬에 **reflog fallback** (Tier 2) 포함: `main`에서 0 매칭이면 `git log -g --since=$UPDATED`로 HEAD reflog 재시도 (기본 90일 보존). 이 경로가 발동하면 Step 7 리포트가 `COMMIT_SOURCE=reflog`로 출처 표시.
3. Reflog도 rolled off면 (>90일 또는 다른 머신의 새 clone) 스킬을 명시 힌트로 호출 ("이 커밋들 기준으로 업데이트: `<sha1>`, `<sha2>`") 하거나 `projects/<name>/worklog/<today>.md`를 직접 편집.

## 진단 명령

문제가 흐릿할 때는 **현재 상태 스냅샷**을 찍으세요:

```bash
# 1. Config SSOT
cat ~/.config/oh-my-obsidian/config.json

# 2. 등록된 cron
crontab -l | grep OMO-CRON

# 3. 최근 cron 로그
tail -20 ~/.local/state/oh-my-obsidian/*.log

# 4. Lint 리포트
ls -lt <vault>/_ops/lint-reports/

# 5. Node / Claude CLI / jq 설치 여부
node --version
command -v claude
command -v jq

# 6. 플러그인 경로 — 해석된 값 + 디스크 실제
echo "$CLAUDE_PLUGIN_ROOT"
jq -r .pluginRoot ~/.config/oh-my-obsidian/config.json 2>/dev/null
ls -la ~/.claude/plugins/cache/oh-my-obsidian/oh-my-obsidian/ 2>/dev/null
ls -la ~/.claude/plugins/marketplaces/oh-my-obsidian/ 2>/dev/null
```

이 6개 블록 출력을 이슈에 붙여주시면 재현이 크게 빨라집니다.
