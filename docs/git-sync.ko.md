# Git 자동 백업 (선택)

[English](git-sync.md) · **한국어**

OMO는 `git-sync.sh`를 제공해 스케줄에 따라 볼트를 git 원격으로 push/pull합니다. `/omo-init`은 이를 **자동 등록하지 않음** — 새 볼트에는 보통 원격·SSH 인증이 없어 sync가 실패만 반복하기 때문. 원격 연결 후 cron 등록은 수동으로 추가.

## 사전 준비

- `jq` 설치 (아래 cron 스니펫이 `~/.config/oh-my-obsidian/config.json`에서 `jq`로 플러그인 경로를 해석).
- push 가능한 git 원격 (GitHub, GitLab, self-hosted 등 표준 호스트).
- 해당 원격 호스트에 등록된 SSH 키.

## 1. 볼트에 원격 연결 (1회)

```bash
cd ~/my-vault
git init
git remote add origin git@github.com:<user>/<vault-repo>.git
git add -A && git commit -m "initial vault"
git push -u origin main
```

## 2. SSH 키 준비

`git-sync.sh`는 다음 순서로 첫 번째 찾은 키를 사용:

1. `$GIT_SYNC_SSH_KEY` (환경변수로 명시 경로)
2. `~/.ssh/id_ed25519`
3. `~/.ssh/id_rsa`

이 중 하나가 원격 호스트에 등록되어 있으면 sync 동작. 아무것도 없으면 기본 git/ssh 설정으로 fallback (경고만 로그).

## 3. crontab에 등록

cron 라인에 `# OMO-CRON:sync` 태그를 붙여 `uninstall-cron.sh` / `omo-uninstall`이 정리 대상으로 인식하게.

```bash
# 플러그인 경로를 config에서 해석 — Claude Code 설치 레이아웃에 관계없이 동작
# (marketplace clone / cache / CLAUDE_PLUGIN_ROOT 심볼릭 링크)
PLUGIN_ROOT=$(jq -r .pluginRoot ~/.config/oh-my-obsidian/config.json)
(crontab -l 2>/dev/null; echo "0 */4 * * * bash $PLUGIN_ROOT/scripts/git-sync.sh >> $HOME/.local/state/oh-my-obsidian/git-sync.log 2>&1 # OMO-CRON:sync") | crontab -
```

스케줄을 바꾸려면 앞부분의 `0 */4 * * *` (4시간마다)만 수정:

- `*/30 * * * *` — 30분마다
- `0 * * * *` — 매시간 정각
- `0 9,21 * * *` — 09:00, 21:00

## 동작 방식

`git-sync.sh`가 호출될 때마다:

1. 락 디렉토리 `/tmp/oh-my-obsidian-git-sync.lock` 획득 (중첩 실행 방지).
2. SSH 키 찾고 `GIT_SSH_COMMAND` 설정.
3. `git fetch --prune origin`
4. `git pull --rebase --autostash origin main` — 로컬 uncommitted 변경을 autostash로 rebase 전 보관, 이후 복구.
5. `git add -A && git commit -m "chore: vault backup YYYY-MM-DD HH:MM"`
6. 변경 없으면 skip, 있으면 `git push origin main`.
7. `qmd` CLI가 설치돼 있으면 인덱스 갱신 (선택).

매 단계가 `~/.local/state/oh-my-obsidian/git-sync.log`에 timestamp와 함께 기록.

## 문제 해결

### 로그 확인

```bash
tail -50 ~/.local/state/oh-my-obsidian/git-sync.log
```

### 자주 발생하는 이슈

- **`No readable SSH key found`** — step 2의 키 중 아무것도 없거나 권한이 `600`이 아님 (`chmod 600 ~/.ssh/id_ed25519`).
- **`Another git-sync process is already running`** — 이전 실행이 죽고 lock이 남음. `rm -rf /tmp/oh-my-obsidian-git-sync.lock`.
- **Rebase 충돌** — autostash가 모든 충돌을 해결하진 못함 — 수동 개입 필요. 전체 절차는 [troubleshooting.ko.md](troubleshooting.ko.md#git-sync-충돌) 참조.
- **Cron은 도는데 push 안 됨** — cron `PATH`에 `git`이 없을 수 있음. crontab 최상단에 `PATH=/usr/local/bin:/usr/bin:/bin` 추가.

### 제거

```bash
/omo-uninstall          # 또는
bash scripts/uninstall-cron.sh
```

`# OMO-CRON:sync` 태그가 붙은 항목은 다른 OMO cron과 함께 제거됩니다.

## 멀티 머신 참고

두 머신이 같은 볼트를 동시에 편집하면 rebase 충돌이 생길 수 있음. 설계 원칙:

- `git pull --rebase --autostash`가 대부분의 가벼운 동시 편집은 흡수.
- 두 머신이 같은 파일의 같은 라인을 편집하면 수동 해결 필요.
- 한 머신을 "주 편집기"로 두고 나머지는 read-only로 운영하는 게 안전.

상세 충돌 해결은 [troubleshooting.ko.md](troubleshooting.ko.md#git-sync-충돌) 참조.
