---
name: omo-project-update
description: Refresh a linked project's vault pages after recent repo activity. Reads commits since index.md's `updated` field, rewrites the "Current state" section, bumps `updated`, optionally appends today's worklog entry, and proposes a decisions/ entry only when commit messages actually signal a decision. Designed to be the one-shot response to the `wiki-staleness-check` hook warning. Non-destructive — every write is behind an AskUserQuestion approval. Use when user says "/omo-project-update [<name>]", "refresh the project wiki", "update the vault project page", "위키 최신화", "프로젝트 업데이트", or after seeing `wiki-check ⚠️ wiki stale:` in the terminal.
origin: oh-my-obsidian
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

# omo-project-update — refresh vault project pages

A **one-shot response** to the staleness-hook warning. Reads commits accumulated since the last `updated` stamp and refreshes the vault's `index.md`, optionally filling in worklog and decisions as well.

**Design principles**:
- One skill covers three axes (index / worklog / decisions — `docs/` is handled by `omo-project-analyze`)
- Every write is gated behind an **AskUserQuestion** approval (no destructive actions)
- `decisions/` is proposed **only when it's naturally warranted** (no forced ADRs)

## When to activate

- `/omo-project-update` or `/omo-project-update <name>`
- Right after the hook warning `[wiki-check] ⚠️ wiki stale:` fires
- "refresh the wiki", "update the project", "clean up the vault"
- "위키 최신화", "프로젝트 업데이트해줘", "볼트 정리"
- Weekly/monthly regular cleanups

## Preflight

### 1. Vault readiness check

```bash
CONFIG=~/.config/oh-my-obsidian/config.json
[ -f "$CONFIG" ] || { echo "/omo-init required"; exit 1; }
VAULT=$(node -e "process.stdout.write(require('$CONFIG').vaultPath)")
```

### 2. Resolve the project name

If no argument is passed, read `project-name:` from the cwd's `CLAUDE.md`; otherwise fall back to `basename $(git rev-parse --show-toplevel)`.

```bash
PROJECT_NAME="${1:-}"
if [ -z "$PROJECT_NAME" ]; then
  REPO_ROOT=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null) || {
    echo "Not a git repo. Pass the project name as an argument or run from inside the project root."
    exit 1
  }
  PROJECT_NAME=$(grep -E '^[-*[:space:]]*project-name[[:space:]]*:' "$REPO_ROOT/CLAUDE.md" 2>/dev/null \
    | head -1 | sed -E 's#^[-*[:space:]]*project-name[[:space:]]*:[[:space:]]*##' | tr -d '` "' )
  PROJECT_NAME="${PROJECT_NAME:-$(basename "$REPO_ROOT")}"
fi
```

### 3. Confirm the project page exists in the vault

```bash
WIKI_DIR="$VAULT/projects/$PROJECT_NAME"
WIKI_INDEX="$WIKI_DIR/index.md"
[ -f "$WIKI_INDEX" ] || {
  echo "The project is not linked to the vault. Run /omo-project-add first."
  exit 1
}
```

## Procedure

### Step 1: Scope the refresh

```bash
UPDATED=$(awk '/^---$/{fm=!fm;next} fm && /^updated:/{sub(/^updated:[[:space:]]*/,"");gsub(/"/,"");print;exit}' "$WIKI_INDEX")
[ -z "$UPDATED" ] && UPDATED="1970-01-01"

GREP='^(feat|fix|refactor|perf)(\([^)]+\))?!?:'

# Tier 1 — reachable main history (normal incremental development case)
COMMITS=$(git -C "$REPO_ROOT" log --since="$UPDATED" \
  --perl-regexp --grep="$GREP" \
  --format='%H%x09%s%x09%b%x00')
COMMIT_SOURCE="main"

# Tier 2 fallback — reflog (post-force-push recovery)
# When a clean-slate release rewrote history (orphan commit + force-push),
# the pre-wipe feat/fix work becomes unreachable from `main` but still lives
# in the HEAD reflog (default 90-day retention, clone-local). Without this
# fallback the skill sees "0 commits" and worklog / decisions capture breaks
# every release cycle.
if [ -z "$COMMITS" ]; then
  COMMITS=$(git -C "$REPO_ROOT" log -g --since="$UPDATED" \
    --perl-regexp --grep="$GREP" \
    --format='%H%x09%s%x09%b%x00' | sort -u)
  [ -n "$COMMITS" ] && COMMIT_SOURCE="reflog"
fi

[ -z "$COMMITS" ] && echo "No meaningful commits since $UPDATED (main + reflog). Proceed with Step 3 only if desired."
```

`COMMITS` is an array of `<sha>\t<subject>\t<body>\0` records. `COMMIT_SOURCE` is `main` or `reflog`; when `reflog`, cite it in the Step 7 report so the user knows the commits are force-push recoveries (no longer reachable from current `main`).

**Optional tier — prior-tag range**: if the reflog has rolled off (> 90 days or the clone is fresh on another machine) and a release tag predates `$UPDATED`, run the same `--grep` against `git log <prior-tag>..HEAD`. Not wired as an automatic tier because the tag to use is project-specific; add it in a per-project override if needed.

### Content language

Rewritten section content — both the section header and the body bullets — follows the **user's working language**. A Korean vault with `## 현재 상태` gets Korean bullets (`- **진행**`, `- **미해결**`, `- **다음**`); an English vault with `## Current state` gets English bullets. Match whatever language is already present in the file rather than forcing a switch.

**Section-name detection (Step 2)**: when locating the existing Current-state section in `index.md`, accept either `## Current state` or `## 현재 상태`. Write back in whatever language the file already uses. Frontmatter keys, wikilink targets, and log.md action enum (`update`, `create`, etc.) stay English as schema anchors.

### Step 2: Rewrite the "Current state" section (AskUserQuestion)

Claude analyzes the commits and drafts a new **Current state** section for `index.md`:

```markdown
## Current state

- **Progress**: (estimate based on commit frequency and themes)
- **Open items**: (TODO/FIXME comments, "WIP" commits, incomplete features)
- **Next**: (cite the next steps if the recent commits imply any)
```

Principle: **no guessing** — observable signals only (commit messages, diff patterns, code TODOs). If a signal is missing, leave the item blank or mark it "needs confirmation".

**Question 1 — apply status rewrite**:
- header: `Rewrite status`
- question: "Replace the 'Current state' section with this draft?\n\n<DRAFT>"
- options:
  - label: `Apply` / description: "Use the draft as-is"
  - label: `Edit` / description: "Tell me what to change; I'll re-propose"
  - label: `Skip` / description: "Leave Current state untouched"

### Step 3: Bump the `updated` field

Only when Step 2 was Apply/Edit, or the user explicitly asked to bump `updated`:

```bash
TODAY=$(date +%Y-%m-%d)
sed -i "s/^updated:.*/updated: $TODAY/" "$WIKI_INDEX"
```

### Step 4: Propose worklog (AskUserQuestion)

Today's worklog file path:

```bash
WORKLOG_PATH="$WIKI_DIR/worklog/$TODAY.md"
```

**Question 2 — worklog**:
- header: `Worklog`
- question: "Write today's worklog into `worklog/$TODAY.md`? (I have a draft summarizing $COMMIT_COUNT commits.)"
- options:
  - label: `Create (Recommended)` / description: "Generate the draft; you review and extend it"
  - label: `Append` / description: "If the file already exists, append only today's commits" (shown only when the file exists)
  - label: `Skip` / description: "No worklog today"

Draft template (Create):
```markdown
---
type: worklog
project: <PROJECT_NAME>
date: <TODAY>
---

# <TODAY> worklog

## Work
- <commit subject 1> (<sha>)
- <commit subject 2> (<sha>)

## Observations
(Key diff patterns and trade-offs. LLM summary.)

## Next
(TODOs and follow-ups; only what's observed.)
```

### Step 5: Decisions detection (conditional proposal)

**Condition**: only propose when commit messages or bodies carry decision signals. Examples:
- Keywords: `decide`, `choose`, `adopt`, `switch to`, `migrate to`, `replace X with Y`, `drop`, `deprecate`
- Commit message contains `BREAKING CHANGE:` or `!:`
- A single commit that restructures multiple modules

If **no signal**, quietly skip Step 5 entirely — do not even show the question. (No forced ADRs.)

When a signal is present:

**Question 3 — decision record**:
- header: `Decision record`
- question: "This commit looks like a decision: '<commit subject>'. Record it as an ADR?"
- options:
  - label: `Draft ADR` / description: "Generate `dec-NNN-<slug>.md` (the user will flesh out context/alternatives/consequences)"
  - label: `Skip` / description: "Not this time"

When `Draft ADR` is selected, compute the next NNN:
```bash
NEXT_NUM=$(ls "$WIKI_DIR/decisions/" 2>/dev/null | grep -oE '^dec-[0-9]+' | sed 's/dec-//' \
  | sort -n | tail -1 | awk '{printf "%03d\n", $1+1}')
NEXT_NUM="${NEXT_NUM:-001}"
```

ADR draft template:
```markdown
---
type: decision
project: <PROJECT_NAME>
dec-id: <NEXT_NUM>
date: <TODAY>
commit: <SHA>
status: proposed
---

# dec-<NEXT_NUM> — <short title>

## Context
(Background observed in the commit body)

## Decision
(What was done — quote the commit message)

## Alternatives
(To be filled in by the user from memory)

## Consequences
(To be filled in by the user from later observations)
```

If multiple decision signals are detected, ask one at a time — cap it at three questions, beyond that `decisions/` becomes noise.

### Step 6: Append to wiki/log.md

Append one row per file that was actually written:

```
| YYYY-MM-DD | update | [[<PROJECT_NAME>/index|<PROJECT_NAME>]] | Current state refreshed (commits=N) |
| YYYY-MM-DD | create | [[<PROJECT_NAME>/worklog/YYYY-MM-DD]]  | daily worklog (commits=N) |
| YYYY-MM-DD | create | [[<PROJECT_NAME>/decisions/dec-NNN-slug]] | ADR draft (commit=<sha>) |
```

Skip rows for any step that was skipped.

### Step 7: Report

```
Project refreshed.

Project: <PROJECT_NAME>
updated: <OLD> → <TODAY>
Commits analyzed: N

Changes applied:
- <vault>/projects/<name>/index.md — Current state rewritten + updated bumped
- <vault>/projects/<name>/worklog/<TODAY>.md — [created | appended | skipped]
- <vault>/projects/<name>/decisions/dec-NNN-*.md — [drafted | not applicable]

Next:
- ADR drafts need context / alternatives / consequences from the user to finish
- If the code structure changed a lot, also run /omo-project-analyze to refresh docs/ snapshots
```

## Input guards

| Problem                                     | Response                                                                              |
|---------------------------------------------|----------------------------------------------------------------------------------------|
| Vault not initialized                       | Point to `/omo-init`                                                                   |
| Project name cannot be resolved             | Tell the user to pass the name explicitly                                              |
| Project page missing                        | Tell the user to run `/omo-project-add` first                                          |
| 0 commits                                   | Skip Step 2; confirm with the user whether to run Step 3 alone                         |
| 100+ commits                                | Too far behind — cap at 20 recent commits and note "see `git log` for the rest"        |

## References

- `<plugin>/hooks/wiki-staleness-check.sh` — the hook that triggers the warning this skill resolves
- `<plugin>/skills/omo-project-add/SKILL.md` — prerequisite (connect the project)
- `<plugin>/skills/omo-project-analyze/SKILL.md` — static-understanding docs refresh (pair with this when code structure changes)
- `<plugin>/schema/wiki-rules.md` — four-axis split (index / docs / worklog / decisions)

## Anti-patterns

- **Forcing a decision record** — don't even show the question when no signal exists.
- **Hallucinating "Current state" content** — don't invent progress/next-steps beyond what the commits show.
- **Overwriting without AskUserQuestion** — every write must be approved.
- **Updating `docs/*.md`** — that's `omo-project-analyze`'s job, out of scope here.
- **Auto-merging a worklog that clobbers user content** — only append, never rewrite existing content.
