---
name: omo-project-analyze
description: Analyze a git project's current state and generate static understanding docs (architecture.md, usage.md) under <vault>/projects/<name>/docs/. Designed to be run once right after /omo-project-add so future sessions can re-ground an agent on the project without re-reading the whole codebase, and re-run later to refresh the snapshot when the repo evolves. Non-destructive — prompts for overwrite / merge / skip when a doc already exists. Use when user says "/omo-project-analyze [<name>]", "analyze the project and write docs", "refresh the understanding docs", "이 프로젝트 분석해서 문서 만들어줘", "프로젝트 이해 문서 갱신", or after an inherited project needs an LLM-parseable reference.
origin: oh-my-obsidian
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, AskUserQuestion
---

# omo-project-analyze — generate and refresh project-understanding docs

Analyze the current git project from an LLM's perspective and write static understanding docs under `<vault>/projects/<name>/docs/`. Analyzing an inherited project once means every subsequent session can rely on these docs for enough context.

**Non-destructive**: when a doc already exists, ask via **AskUserQuestion** — `overwrite / merge / skip`.

**Role separation (no duplication)**:
- `index.md` — one-page summary hub (at-a-glance)
- `docs/architecture.md` — system structure, modules, data flow
- `docs/usage.md` — runtime, configuration, API, deployment
- `worklog/` — time axis
- `decisions/` — decisions (ADRs)

## When to activate

- `/omo-project-analyze` or `/omo-project-analyze <name>`
- Auto-chained from the Yes branch of `/omo-project-add`
- "analyze this project and write docs", "refresh the understanding docs", "prepare hand-off docs"
- "이 프로젝트 분석해서 문서 만들어줘", "프로젝트 이해 문서 갱신", "인수인계 문서 정리"
- Re-run when the snapshot goes stale (the code changed so much that the previous architecture.md no longer reflects reality)

## Preflight

### 1. Vault readiness check

```bash
CONFIG=~/.config/oh-my-obsidian/config.json
[ -f "$CONFIG" ] || {
  echo "Vault not initialized. Run /omo-init <path> first."
  exit 1
}
VAULT=$(node -e "process.stdout.write(require('$CONFIG').vaultPath)")
```

### 2. Must be inside a git repo

```bash
REPO_ROOT=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null)
[ -z "$REPO_ROOT" ] && {
  echo "Current directory is not a git repo. Run this from the project root."
  exit 1
}
```

### 3. Resolve the project name

If an argument is passed, use it. Otherwise prefer the `project-name:` line in `CLAUDE.md`; fall back to `basename "$REPO_ROOT"`.

```bash
PROJECT_NAME="${1:-}"
if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME=$(grep -E '^- project-name:' "$REPO_ROOT/CLAUDE.md" 2>/dev/null | head -1 | sed 's/.*project-name: *//' | tr -d ' ')
  PROJECT_NAME="${PROJECT_NAME:-$(basename "$REPO_ROOT")}"
fi
```

### 4. Confirm the project page exists in the vault

```bash
WIKI_PROJECT_DIR="$VAULT/projects/$PROJECT_NAME"
[ -d "$WIKI_PROJECT_DIR" ] || {
  echo "The project is not linked to the vault. Run /omo-project-add first."
  exit 1
}
DOCS_DIR="$WIKI_PROJECT_DIR/docs"
mkdir -p "$DOCS_DIR"
```

## Procedure

### Step 1: Repo scan

Collect the material the LLM will analyze:

```bash
# Documents
ls "$REPO_ROOT"/README* "$REPO_ROOT"/CLAUDE.md 2>/dev/null

# Build / dependency metadata
ls "$REPO_ROOT"/package.json "$REPO_ROOT"/requirements*.txt \
   "$REPO_ROOT"/pyproject.toml "$REPO_ROOT"/Cargo.toml \
   "$REPO_ROOT"/go.mod "$REPO_ROOT"/pom.xml "$REPO_ROOT"/Gemfile \
   "$REPO_ROOT"/Makefile "$REPO_ROOT"/Dockerfile \
   "$REPO_ROOT"/docker-compose.yml 2>/dev/null

# Entry-point candidates (by language)
# node:   src/index.*, src/main.*
# python: <package>/__init__.py, main.py, app.py
# go:     cmd/*/main.go
# rust:   src/main.rs, src/lib.rs

# Structure snapshot (2-depth)
cd "$REPO_ROOT" && find . -maxdepth 2 -type d ! -path '*/\.*' ! -path '*/node_modules*' \
  ! -path '*/target*' ! -path '*/dist*' ! -path '*/build*' | sort

# Snapshot SHA
GIT_SHA=$(git -C "$REPO_ROOT" rev-parse --short HEAD)
```

Claude opens the necessary files via Read / Glob / Grep. **No guessing** — only files, dependencies, and directories you actually observed may appear in the docs.

### Step 2: Detect existing docs → choose write mode

For each doc (`architecture.md`, `usage.md`) independently:

```bash
DOC_PATH="$DOCS_DIR/architecture.md"   # or usage.md
[ -f "$DOC_PATH" ] && EXISTS=1 || EXISTS=0
```

**If it exists, ask via AskUserQuestion**:

- header: `Existing <doc>`
- question: "`docs/<doc>.md` already exists. How should we proceed?"
- options:
  - label: `Overwrite` / description: "Replace entirely with the new analysis (git preserves the diff)"
  - label: `Merge` / description: "Read the existing content as supplementary context, then rewrite"
  - label: `Skip` / description: "Leave this doc untouched"

Store per-doc modes as `MODE_ARCH` and `MODE_USAGE`.

### Content language

Generated page content — both section headers and body prose — follows the **user's working language** (the language the user invoked the skill in). A Korean user gets `## 개요 / ## 핵심 모듈 / ## 관찰 사항`; an English user gets `## Overview / ## Core modules / ## Observations`. This keeps each user's vault internally consistent.

**Stays English regardless of working language** (schema anchors):
- Frontmatter keys (`type`, `project`, `doc`, `created`, `updated`, `status`, `source-commit`)
- Enum values in frontmatter (`project-doc`, `active`, …) and `wiki/log.md` action column (`analyze`, `ingest`, etc.)
- Wikilink targets, file slugs, technical identifiers (Claude Code commands, env var names)
- The `project-name:` contract key in project `CLAUDE.md` (cross-machine contract — never translate)

### Step 3: Write architecture.md

Run when `MODE_ARCH != skip`. For `Merge`, read the existing file first and rewrite "only the parts that need improvement".

```markdown
---
type: project-doc
project: <PROJECT_NAME>
doc: architecture
created: <TODAY>
updated: <TODAY>
status: active
source-commit: <GIT_SHA_SHORT>
---

# <PROJECT_NAME> — Architecture

## Overview
(1–2 paragraphs on the problem the project solves — stay within what README reveals)

## High-level structure
(Directory-tree summary. Based on the real 2-depth scan. One-line role per top-level directory)

## Core modules
(3–7 key modules starting from the entry points. For each module:
- file path
- one-line role
- main exports / dependencies)

## Data flow
(How requests/events enter and leave. Only paths observed in the actual code)

## External dependencies
(**Runtime** dependencies identified from package.json / requirements / Cargo.toml etc., with a one-line role)

## Observations
(Caveats discovered during analysis, e.g. circular imports, untested modules, legacy areas)
```

#### Diagrams (Mermaid)

Architecture is easier to absorb visually. Embed **up to three** Mermaid diagrams inside `architecture.md`, each in the section it illustrates:

| Diagram              | Hosting section            | Mermaid type   | Emit only when                                                              |
|----------------------|----------------------------|----------------|------------------------------------------------------------------------------|
| Directory tree       | `## High-level structure`  | `graph TD`     | 2-depth scan returned ≥ 2 top-level dirs with content                       |
| Module dependencies  | `## Core modules`          | `graph LR`     | ≥ 3 inter-module imports/requires were actually grep'd from source          |
| Data flow            | `## Data flow`             | `flowchart LR` | the flow has ≥ 3 distinct hops (entry → intermediate → sink); skip if linear |

**Grounding rules (non-negotiable — same "no hallucination" bar as the prose)**:
- Nodes must be **observed artifacts**: a file path, directory name, module name, script, or named entity actually read.
- Edges must be **observed relations**: an import statement, a call site, a cron/hook invocation, a CLI → script dispatch. If you cannot point to the file/line that establishes the edge, it does not go in the diagram.
- If an edge is plausible but unverified, write it as a `%% speculative: <desc>` comment line — never as a real edge.
- Every diagram applies `<plugin>/schema/mermaid-style.md`: include the `%%{init: ...}%%` theme block at the top and use the palette's `classDef` colors.
- Diagrams that would have only 1–2 nodes are noise — skip and leave a single prose line like "structure is flat; no diagram warranted".

**Principles**:
- Quote observed file paths verbatim (prefer `src/foo/bar.ts:42`).
- Record the snapshot git SHA in the `source-commit` frontmatter — later staleness checks rely on it.
- No generic "projects like this usually…" phrasing.
- Mermaid diagrams follow the Grounding rules above and live inside the section they illustrate (no standalone Diagrams section).

### Step 4: Write usage.md

Run when `MODE_USAGE != skip`.

```markdown
---
type: project-doc
project: <PROJECT_NAME>
doc: usage
created: <TODAY>
updated: <TODAY>
status: active
source-commit: <GIT_SHA_SHORT>
---

# <PROJECT_NAME> — Usage

## Setup
(Build / dependency install. README install section + actual npm/pip/cargo commands)

## Configuration
(Environment variables, config file paths, defaults. Only env vars actually referenced in code)

## Running
(Local run commands. Observed from Makefile / package.json scripts / Dockerfile)

## Public API / Entry points
(CLI flags, HTTP endpoints, function signatures. Only observable surface)

## Testing
(Test runner, command, coverage tool)

## Deployment
(CI/CD pipeline, Dockerfile, deployment manifests. Only what's observable)

## Observations
(Gotchas during use, undocumented conventions)
```

**Optional sequence diagram** (usage.md): when the project exposes **≥ 2 distinct entry surfaces** (e.g. CLI + HTTP, slash command + cron, hook + script), embed a single `sequenceDiagram` inside `## Public API / Entry points` showing the typical call chain. Same Grounding rules as architecture.md — only observed dispatch points. Skip for single-entry tools.

### Step 5: Refresh index.md

Two passes, both idempotent. The skill owns only these touch points; the rest of `index.md` (Architecture body, Current state, narrative sections) belongs to the user.

**5a. Bump frontmatter**

```bash
sed -i "s/^updated:.*/updated: $TODAY/" "$WIKI_PROJECT_DIR/index.md"
```

**5b. Inject Docs pointer into the Related links section**

Goal: guarantee that `docs/architecture.md` and `docs/usage.md` are reachable from the one-page hub, without rewriting sections the user has hand-edited.

Procedure:

1. Locate the Related links section. Accept both English (`## Related links`) and localized variants — most commonly Korean (`## 관련 링크`). Use whatever header already exists; never rename it.
2. Build the pointer line from docs **actually written/refreshed in this run** (skip those whose `MODE_* == skip`):
   - Both written → `- **Docs**: [[<PROJECT_NAME>/docs/architecture]] · [[<PROJECT_NAME>/docs/usage]]`
   - Only one written → link only that one.
3. If a line starting with `- **Docs**:` already exists inside the section, **replace it in place** (keeps wording in sync with the latest run).
4. Otherwise, insert it as the **first** list item of the Related links section. User-added items (Entities / Concepts / Decisions / custom labels) are preserved below it.
5. If the Related links section does not exist at all, skip silently — the user may have removed it intentionally.

Run **5b** only when at least one doc was written/refreshed in this session. Pure-skip runs touch only `updated:`.

### Step 6: Record in wiki/log.md

One row per doc actually written/refreshed:

```
| YYYY-MM-DD | analyze | [[<PROJECT_NAME>/docs/architecture]] | project analysis (mode=<overwrite|merge|fresh>) source-commit=<sha> |
| YYYY-MM-DD | analyze | [[<PROJECT_NAME>/docs/usage]]        | project analysis (mode=<overwrite|merge|fresh>) source-commit=<sha> |
```

Skip rows for docs that were skipped.

### Step 7: Report

```
Project analysis complete.

Project: <PROJECT_NAME>
source-commit: <sha>

Docs written / refreshed:
- <vault>/projects/<name>/docs/architecture.md (mode=<m1>)
- <vault>/projects/<name>/docs/usage.md (mode=<m2>)

Effect:
- In future sessions, Read only these two files and the agent re-grounds quickly
- `source-commit` gives a baseline for later staleness checks

To re-analyze: /omo-project-analyze <name>
```

## Input guards

| Problem                               | Response                                                                                                     |
|---------------------------------------|--------------------------------------------------------------------------------------------------------------|
| Vault not initialized                 | Point to `/omo-init` and exit                                                                                |
| Not a git repo                        | Explain and exit                                                                                             |
| Project not linked to the vault       | Point to `/omo-project-add` first and exit                                                                   |
| Repo with essentially no source       | Fill only `High-level structure`; mark other sections "nothing observed"                                    |
| Very large monorepo                   | Stop at 2-depth; note "recommend per-sub-package analysis" under Observations                               |
| Too flat to diagram (≤2 nodes/edges)  | Skip the Mermaid block for that section; prose-only is fine                                                  |

## References

- `<plugin>/skills/omo-project-add/SKILL.md` — prerequisite for this skill
- `<plugin>/schema/wiki-rules.md` — project sub-structure definition
- `<plugin>/schema/page-types.md` — `project-doc` page type contract
- `<plugin>/schema/mermaid-style.md` — theme init, classDef palette, subgraph styles applied to every diagram this skill emits

## Anti-patterns

- Writing content you did not observe as if it were general knowledge (no hallucination).
- **Silently overwriting** an existing doc (always go through AskUserQuestion).
- Creating project-agnostic docs under `docs/` (shared docs belong in `wiki/guides/`).
- Repeating `index.md`-level summaries inside `docs/` (no redundant value — these docs are **detailed**).
- Omitting `source-commit` (without it, future staleness comparison is impossible).
- Rewriting user-edited sections of `index.md` (Architecture body, Current state). The skill owns only the `updated:` frontmatter and the `- **Docs**:` pointer line in Related links — everything else stays as the user left it.
- **Inventing Mermaid nodes/edges** — only observed files, modules, and call sites. Plausible-but-unverified relations go in `%% speculative:` comments, never as real edges. A wrong diagram is worse than no diagram.
