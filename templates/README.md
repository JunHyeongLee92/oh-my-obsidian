# Obsidian Vault

**English** · [한국어](README.ko.md)

A personal knowledge base maintained by an LLM. Operated via the [oh-my-obsidian](https://github.com/JunHyeongLee92/oh-my-obsidian) plugin; this repository holds **data only** — rules, scripts, and schema live in the plugin.

## Layout

```
<vault>/
├── wiki/                      # LLM-maintained interlinked wiki (derived from _sources/)
│   ├── index.md               #   Full index (pages grouped by category)
│   ├── log.md                 #   Change history (append-only: ingest/create/update/delete/lint/promoted/analyze)
│   ├── entities/              #   People, tools, services, products, organizations
│   ├── concepts/              #   Patterns, methodology, technical ideas
│   ├── guides/                #   How-to guides
│   ├── summaries/             #   One summary per source (ingest output)
│   └── digests/               #   Weekly re-synthesis (Monday 03:30 cron)
├── projects/                  # User · LLM collaboration workspace (per linked repo)
│   └── <name>/
│       ├── index.md           #   Project overview · current state (single-page hub) — created by /omo-project-add
│       ├── worklog/           #   Daily work log — created by /omo-project-add
│       ├── decisions/         #   ADR-style decision records — created by /omo-project-add
│       ├── docs/              #   Static understanding docs (architecture.md, usage.md) — created by /omo-project-analyze
│       └── jira/              #   (Optional) Jira ticket notes — created manually by user
├── _sources/                  # External originals (immutable after first save)
│   ├── articles/              #   Web articles
│   ├── papers/                #   Papers
│   ├── conversations/         #   Conversations, meeting notes
│   ├── assets/                #   Images, attachments
│   └── misc/                  #   Misc
├── _ops/
│   ├── lint-reports/          # Lint output (only latest-<hostname>.md per machine is git-tracked)
│   └── templates/             # Obsidian Templater templates (10 types, for manual page creation)
├── .obsidian/                 # Obsidian config (templates.json points to _ops/templates)
├── README.md                  # This document
└── .gitignore
```

**External SSOT**: `~/.config/oh-my-obsidian/config.json` — stores `vaultPath`, `pluginRoot`, `syncMode`. `/omo-init` creates it on first run, and all skills/scripts resolve paths through this file.

**Page-type rules**: Pages under each folder follow a required-section + frontmatter schema. See the plugin's `schema/page-types.md` and `schema/frontmatter-spec.md` for details.

## How to use

- `/omo-ingest <URL>` — Add a URL to the vault (original → `_sources/`, structured → `wiki/entities` · `wiki/concepts` · `wiki/summaries`)
  - Example: `/omo-ingest https://github.com/anthropics/claude-code`
  - Natural language: "add this URL to the wiki https://..."

- `/omo-query <keyword>` — Search the vault; if the answer has reusable value, auto-promote it to a new page
  - Example: `/omo-query LangGraph agent pattern`
  - Natural language: "find LangGraph in the wiki"

- `/omo-project-add` — Link the current git project to vault `projects/<name>/` (also records the project name in the project's CLAUDE.md)
  - Example: run `/omo-project-add` from the project root
  - Natural language: "link this project to the wiki"

- `/omo-project-analyze` — Analyze the repo and produce `projects/<name>/docs/architecture.md` · `usage.md` (for fast re-ground in later sessions)
  - Example: run `/omo-project-analyze` from the project root
  - Natural language: "analyze this project and write docs"

- `/omo-project-update` — One-shot answer to the `wiki-staleness-check` hook warning (rewrites Current state + bumps `updated` + drafts worklog / ADR when signals warrant)
  - Example: `/omo-project-update <name>` (no arg → resolved from current cwd)
  - Natural language: "refresh the project wiki"

- `/omo-study <URL|topic>` — Vault-grounded step-by-step learning (with MCQ step checks)
  - Example: `/omo-study differential privacy`
  - Natural language: "teach me this https://..."

- `/omo-lint` — Schema / link / frontmatter consistency check; applies CRITICAL fixes after user approval
  - Example: `/omo-lint` (no argument)

- `/omo-digest` — Weekly re-synthesis (default cron: auto-generated Monday 03:30)
  - Manual on-demand generation also supported

## Manual page creation (Obsidian)

In Obsidian: `Ctrl/Cmd+P` → "Insert template" → pick one of the 10 templates under `_ops/templates/`:

`wiki-entity` · `wiki-concept` · `wiki-guide` · `wiki-summary` · `wiki-project` · `wiki-decision` · `wiki-digest` · `wiki-jira` · `work-log-entry` · `source-ingest`

Skills (`/omo-ingest` etc.) follow the same schema when auto-generating, so manual and automated pages share a consistent structure.

## Automation

Cron jobs registered by `/omo-init` (identified by the `# OMO-CRON:<name>` tag):

- **Daily 03:00** — `lint.sh` (detect schema violations; report only)
- **Daily 03:15** — `qmd-update.sh` (refresh the Obsidian index)
- **Monday 03:30** — `weekly-digest.sh` (Claude CLI call for weekly re-synthesis)

`git-sync` needs remote + credential setup, so it is **not** auto-registered (see Tip below).

## Hook (automatic warning)

- **wiki-staleness-check** — On a `feat/fix/refactor/perf` commit in a git project, this hook compares the `updated` field in the linked `projects/<name>/index.md` and, if stale, prints `[wiki-check] ⚠️ wiki stale: ...`. To resolve: run `/omo-project-update <name>` for a **one-shot fix** (reads recent commits, rewrites Current state, bumps `updated`, and drafts worklog / ADR when needed).
- If the project isn't linked to the vault yet, a `/omo-project-add` guidance message is shown instead of the stale warning.

## Tip — Git auto-backup (optional)

Connect this vault to a git remote (e.g. GitHub), then register the plugin's `git-sync.sh` in cron to periodically auto-backup. Especially useful when sharing one vault across multiple machines.

```bash
# 1) Connect the vault to a remote (once)
cd <vault>
git init
git remote add origin git@github.com:<user>/<vault-repo>.git
git add -A && git commit -m "initial vault"
git push -u origin main

# 2) Prepare an SSH key (~/.ssh/id_ed25519 or id_rsa)

# 3) Register cron (the OMO-CRON tag lets uninstall-cron pick it up)
#    Plugin path varies per Claude Code install — resolve it from config
PLUGIN_ROOT=$(jq -r .pluginRoot ~/.config/oh-my-obsidian/config.json)
(crontab -l 2>/dev/null; echo "0 */4 * * * bash $PLUGIN_ROOT/scripts/git-sync.sh >> $HOME/.local/state/oh-my-obsidian/git-sync.log 2>&1 # OMO-CRON:sync") | crontab -
```

Without the remote / SSH setup, sync just keeps failing, so it is excluded from auto-registration.
