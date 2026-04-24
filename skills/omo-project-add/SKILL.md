---
name: omo-project-add
description: Link the current git project to the user's oh-my-obsidian vault. Detects project from cwd, adds a '## oh-my-obsidian' section with '- project-name: <name>' to the project CLAUDE.md, scaffolds <vault>/projects/<name>/ with index.md + worklog/ + decisions/, and registers it in wiki/index.md and wiki/log.md. Non-destructive — links to an existing wiki folder when one is already present. Use when the user says "/omo-project-add [<name>]", "link this project to the vault", "register this project with omo", "이 프로젝트 위키에 연동해줘", "omo 프로젝트 등록", or right after cloning a repo that should be tracked in the vault.
origin: oh-my-obsidian
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

# omo-project-add — link project ↔ vault

Register the current git project with the oh-my-obsidian vault. Writes a single `project-name: <name>` line into the project's `CLAUDE.md` so the `wiki-staleness-check` hook works, and scaffolds the project page under the vault.

**Non-destructive**: when `projects/<name>/` already exists, the skill treats it as a **Link-to-existing** situation (safe to re-run after `git clone` on another machine).

**Why this key is literal**: `hooks/wiki-staleness-check.sh` detects the project by grepping for the literal string `project-name:`. Do **not** customize this key on individual machines — it is a cross-machine contract shared by the hook and the skill, so every clone of the same project must use the identical line.

## When to activate

- `/omo-project-add` or `/omo-project-add <name>`
- "link this project to the vault", "register the project in the wiki"
- "이 프로젝트 위키에 연동해줘", "omo 프로젝트 등록", "프로젝트 위키 시작"
- Right after `git clone` when you want to re-attach the project to an existing vault page

## Preflight

### 1. Vault readiness check

```bash
CONFIG=~/.config/oh-my-obsidian/config.json
[ -f "$CONFIG" ] || {
  echo "Vault not initialized. Run /omo-init <path> first."
  exit 1
}
VAULT=$(node -e "process.stdout.write(require('$CONFIG').vaultPath)")
[ -d "$VAULT/projects" ] || mkdir -p "$VAULT/projects"
```

### 2. Must be inside a git repo

```bash
REPO_ROOT=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null)
[ -z "$REPO_ROOT" ] && {
  echo "Current directory is not a git repo. Run this from the project root."
  exit 1
}
```

### 3. Refuse to register the vault itself

```bash
case "$REPO_ROOT" in
  "$VAULT"|"$VAULT"/*)
    echo "Refusing: the vault itself cannot be registered as a project."
    exit 0
    ;;
esac
```

### 4. Auto-detection

```bash
DETECTED_NAME=$(basename "$REPO_ROOT")
REPO_URL=$(git -C "$REPO_ROOT" config --get remote.origin.url 2>/dev/null || echo "")
```

## Procedure

### Step 1: Confirm the project name (AskUserQuestion)

**Question 1 — project name**:
- header: `Project`
- question: "Confirm the project name. (Used as the slug under `projects/` in the vault.)"
- multiSelect: false
- options:
  - label: `Use '<DETECTED_NAME>' (Recommended)` / description: "repo folder name as-is — kebab-case"
  - label: `Other` (tool-provided) / description: enter a custom name

Pick = `PROJECT_NAME`. kebab-case is recommended (warn but allow when the user enters spaces / uppercase).

### Step 2: Check for an existing wiki folder

```bash
WIKI_PROJECT_DIR="$VAULT/projects/$PROJECT_NAME"
```

If the folder already exists, ask via **AskUserQuestion**:

**Question 2 — existing wiki**:
- header: `Existing wiki`
- question: "`projects/$PROJECT_NAME/` already exists. Link to it?"
- options:
  - label: `Link to existing (Recommended)` / description: "Leave the wiki folder alone and just register in the project CLAUDE.md (already-created on another machine)"
  - label: `Cancel` / description: "Restart with a different name"

On Cancel → return to Step 1 for a new name, or exit.

### Step 3: Update CLAUDE.md

Inspect the current state of the project's `CLAUDE.md`:

```bash
CLAUDE_MD="$REPO_ROOT/CLAUDE.md"
```

| Detected                                  | Action                                                                              |
|-------------------------------------------|-------------------------------------------------------------------------------------|
| File missing                              | Create from the "CLAUDE.md section template" below                                  |
| No `## oh-my-obsidian` section            | Append the section to the end of the file                                           |
| Section present but `project-name:` missing | Add the line inside the existing section                                            |
| `project-name: <existing>` already present  | Confirm via Q3 below                                                                |

**Question 3 — existing project name** (only when the existing value differs from `PROJECT_NAME`):
- header: `Replace name`
- question: "CLAUDE.md already has 'project-name: <existing>'. How should we handle it?"
- options:
  - label: `Replace with '$PROJECT_NAME'` / description: "Overwrite the existing value with the new name"
  - label: `Skip` / description: "Leave CLAUDE.md as-is and go to Step 4"

If the existing value matches, skip Q3 (no-op).

**Question 4 — legacy key** (only when a `위키 경로:` line is detected):
- header: `Legacy key`
- question: "CLAUDE.md has a '위키 경로: ...' line (legacy format). Remove it?"
- options:
  - label: `Remove` / description: "Clean up the pre-plugin remnant (recommended)"
  - label: `Keep` / description: "Leave it (does not affect the staleness hook)"

### CLAUDE.md section template

```markdown
## oh-my-obsidian

- project-name: <PROJECT_NAME>
```

The `wiki-staleness-check` hook reads the `project-name:` line and resolves `<vault>/projects/<name>/index.md` as the staleness target. Never use an absolute path.

### Step 4: Scaffold the vault project page

When not `Link to existing` (or the folder never existed):

```bash
mkdir -p "$WIKI_PROJECT_DIR/worklog" "$WIKI_PROJECT_DIR/decisions"
touch "$WIKI_PROJECT_DIR/worklog/.gitkeep"
touch "$WIKI_PROJECT_DIR/decisions/.gitkeep"
```

If `index.md` is missing, create it following the **`_ops/templates/wiki-project.md`** structure (substitute Templater tokens: `{{date:YYYY-MM-DD}}` → today, `{{title}}` → `PROJECT_NAME`):

```markdown
---
type: project
created: <TODAY>
updated: <TODAY>
status: active
project-status: planning
repo-url: "<REPO_URL>"
tech-stack: []
tags: []
aliases: []
---

# <PROJECT_NAME>

<DESCRIPTION_LINE>

## Current state

- **Progress**: 
- **Open items**: 
- **Next**: 

## Architecture

(Core structure summary. Move detailed content into separate concept / guide pages.)

## Related links

- **Entities**: 
- **Concepts**: 
- **Decisions**: 
```

`<DESCRIPTION_LINE>` is resolved in Step 5.

### Step 5: Decide the one-line description (AskUserQuestion)

Attempt auto-extraction from the project README:

```bash
AUTO_DESC=$(awk '/^[^#-]/ && NF { print; exit }' "$REPO_ROOT/README.md" 2>/dev/null | head -c 120)
```

(First meaningful line, skipping blanks / comments / lists.)

**Question 5 — description**:
- header: `Description`
- question: "One-line description for the wiki index. (auto: '$AUTO_DESC')"
- options:
  - label: `Use auto` / description: "the README first line as-is"
  - label: `Other` (free input) / description: user types a new description

If `AUTO_DESC` is empty or meaningless, hide the `Use auto` option and leave only `Other`. Selection = `DESCRIPTION`.

### Step 6: Register in wiki/index.md

For `Link to existing` the entry may already be there — check first:

```bash
grep -q "\[\[$PROJECT_NAME/index" "$VAULT/wiki/index.md" 2>/dev/null && {
  echo "Already registered in index, skipping."
} || {
  # Append one line under the Projects section
  # Format: - [[<name>/index|<name>]] — <DESCRIPTION>
}
```

Edit target: under `## Projects`, append one line to the end of the list. Also bump the `updated: YYYY-MM-DD` frontmatter to today.

### Step 7: Append to wiki/log.md

```
| YYYY-MM-DD | create | [[<PROJECT_NAME>/index|<PROJECT_NAME>]] | project wiki registered: <REPO_URL> (mode=<fresh|link-existing>) |
```

### Step 8: Offer to analyze now (AskUserQuestion)

For hand-off or fresh onboarding, generating the understanding docs immediately means later sessions can rely on them.

**Question 6 — analyze now**:
- header: `Analyze now`
- question: "Run repo analysis now and generate `docs/architecture.md` + `docs/usage.md`? (You can always re-run via `/omo-project-analyze` later.)"
- multiSelect: false
- options:
  - label: `Yes (Recommended)` / description: "read the repo and produce the two understanding docs — chain into /omo-project-analyze"
  - label: `Skip` / description: "call /omo-project-analyze manually later"

On `Yes`: continue by **executing the `/omo-project-analyze` Procedure** in the current session, passing `PROJECT_NAME` so it does not have to re-resolve.

### Step 9: Report

Short report (in the user's working language):

```
Project linked.

Project: <PROJECT_NAME>
Repo: <REPO_URL>
Mode: fresh (new folder) | link-existing (linked to existing folder)

Modified / created files:
- <repo>/CLAUDE.md (section / line added)
- <vault>/projects/<name>/index.md (scaffolded)
- <vault>/projects/<name>/{worklog,decisions}/
- <vault>/wiki/index.md (Projects registered)
- <vault>/wiki/log.md (create log)

Effect:
- On every git commit in this project, the wiki-staleness-check hook
  will compare index.md's `updated` with recent feat/fix/refactor commits
  and warn if the vault is out of date.

Next steps:
- /omo-project-analyze to write the understanding docs (if Step 8 was Skip)
- /omo-ingest <URL> to add related material
- projects/<name>/worklog/YYYY-MM-DD.md for daily work
- projects/<name>/decisions/dec-NNN-*.md for ADRs
```

## Input guards

| Problem                                  | Response                                                                             |
|------------------------------------------|--------------------------------------------------------------------------------------|
| Vault not initialized                    | Point to `/omo-init` and exit                                                        |
| Not a git repo                           | Explain and exit (no manual-path override)                                           |
| Invoked inside the vault                 | Warn and exit                                                                        |
| Project name looks like an absolute path | Reject; ask for a slug                                                               |
| Project name has spaces / uppercase      | Warn (kebab-case recommended) but allow if the user insists                          |

## References

- `<plugin>/schema/wiki-rules.md` — project-management procedure
- `<plugin>/schema/page-types.md` — Project page required / optional sections
- `<plugin>/templates/_ops/templates/wiki-project.md` — page structure blueprint
- `<plugin>/hooks/wiki-staleness-check.sh` — reads the `project-name:` line registered by this skill

## Anti-patterns

- Putting an **absolute path** into the project `CLAUDE.md` (do not recreate the old `위키 경로:` form).
- Overwriting existing `projects/<name>/` contents (destructive — violates the skill's design).
- **Adding** a legacy `위키 경로:` key (only detect/remove — never write new).
- Registering the vault itself as a project.
- Replacing an existing `project-name: <other>` without user consent.
