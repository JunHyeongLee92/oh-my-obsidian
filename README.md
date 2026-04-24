# oh-my-obsidian (OMO)

**English** · [한국어](README.ko.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-plugin-7132f5?style=flat-square)](https://claude.com/claude-code)
[![Node.js](https://img.shields.io/badge/Node.js-20%2B-339933?style=flat-square&logo=node.js&logoColor=white)](https://nodejs.org)
[![Issues](https://img.shields.io/github/issues/JunHyeongLee92/oh-my-obsidian?style=flat-square)](https://github.com/JunHyeongLee92/oh-my-obsidian/issues)

**Turn any Obsidian vault into an LLM-maintained wiki.**

An implementation of [Andrej Karpathy's LLM wiki concept](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f).  
Three layers: immutable raw sources, an LLM-curated wiki, and a schema that defines the conventions.

> [!NOTE]
> **What is the LLM wiki concept (Karpathy)?**
> Standard RAG re-reads raw sources for every query — the model never _accumulates_ what it learned.  
> An LLM wiki flips that: the LLM itself maintains a persistent, structured, cross-linked knowledge base.  
> New sources get filed, summarized, and linked; reusable answers get promoted into new pages. The knowledge base **compounds** over time instead of being rediscovered on every turn.

A Claude Code plugin. Claude runs as an autonomous curator for your vault — without prompts, it will:

- store URLs and cross-link them with auto-generated summary / entity / concept pages
- answer questions against the vault, promoting reusable answers into new pages
- warn about stale wiki entries on project commits

Works with slash commands (`/omo-ingest ...`) and natural language ("add this URL to the wiki").

![oh-my-obsidian architecture](docs/architecture.png)

> Multiple git projects share a single vault as a central knowledge hub. See [Plugin concepts](docs/concepts.md) for details.

## How knowledge compounds

OMO **locks answers as wiki pages** so the same discovery isn't repeated. Search itself grows the wiki.

![Knowledge compounding loop](docs/compounding.png)

- **`/omo-ingest <URL>`** — the original is stored immutably in `_sources/`; the LLM structures it into entity / concept / summary pages under `wiki/`
- **`/omo-query <question>`** — 3-tier search, then synthesize
  1. `wiki/index.md` + `[[wikilinks]]` graph traversal
  2. (miss) `qmd` hybrid search (BM25 + semantic)
  3. (miss) `Grep` full-vault scan
  - If reusable, **auto-promote the answer into a new wiki page** → next time, Tier 1 resolves it directly
- **Result**: as the wiki grows, Tier 1 hit rate rises and Tier 2/3 calls drop. Queries themselves grow the wiki.

## Why OMO?

A vault you maintain alone just piles up and falls out of use. OMO lets Claude **maintain it autonomously**.

| Old workflow                             | OMO                                                                                           |
| ---------------------------------------- | --------------------------------------------------------------------------------------------- |
| Bookmark a URL, then forget it           | `/omo-ingest` → save source + auto-generate entity / concept / summary pages + cross-link     |
| "I researched this before…" — can't find | `/omo-query` → answers from the vault; reusable answers auto-promoted into new pages          |
| Re-research the same topic per project   | `/omo-project-add` → project `CLAUDE.md` points into the vault, warns on stale refs at commit |
| Notes pile up, structure collapses       | Schema + daily lint keeps the vault navigable six months later                                |
| Starting each new topic from scratch     | `/omo-study` → vault-grounded step-by-step walkthrough with MCQ checks                        |

## Install

**Linux / macOS** (Windows via WSL2). Requires Claude Code + Node.js 20+.

```bash
/plugin marketplace add https://github.com/JunHyeongLee92/oh-my-obsidian
/plugin install oh-my-obsidian
/reload-plugins
/omo-init ~/my-vault
```

## Try it

```bash
/omo-ingest https://www.anthropic.com/news/claude-4-7
/omo-query "What changed in Claude 4.7 vs earlier versions"
/omo-study "prompt caching"
```

Natural language works too: "add this URL to the wiki https://...".

## Skills

| Skill                  | Role                                                                                                                                                |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/omo-init`            | Initialize the vault + register cron jobs                                                                                                           |
| `/omo-ingest`          | Ingest a URL into the vault (source + summary / entity / concept)                                                                                   |
| `/omo-query`           | Search the vault + auto-promote reusable answers                                                                                                    |
| `/omo-project-add`     | Link the current git project to the vault                                                                                                           |
| `/omo-project-analyze` | Analyze the repo and generate `docs/architecture.md` · `docs/usage.md` under the project — reusable across sessions                                 |
| `/omo-project-update`  | One-shot answer to the `wiki-staleness-check` warning — rewrites `Current state`, bumps `updated`, proposes worklog / ADR only when signals warrant |
| `/omo-study`           | Step-by-step learning grounded in vault context (MCQ checks)                                                                                        |
| `/omo-lint`            | Schema / link checks, with opt-in auto-fix for CRITICAL items                                                                                       |
| `/omo-digest`          | Weekly re-synthesis (cron auto + manual invocation)                                                                                                 |
| `/omo-uninstall`       | Remove OMO cron jobs + optional config deletion                                                                                                     |

## Docs

- [Plugin concepts](docs/concepts.md) — architecture · search · vault layout · cron schedule
- [Troubleshooting](docs/troubleshooting.md) — install · cron · lint · ingest issues
- [Git backup](docs/git-sync.md) — remote auto-sync for the vault
- [Contributing](CONTRIBUTING.md) · [Changelog](CHANGELOG.md) · [Issues](https://github.com/JunHyeongLee92/oh-my-obsidian/issues)

## Acknowledgments

[Claude Code](https://claude.com/claude-code) · [Obsidian](https://obsidian.md) · [Playwright](https://playwright.dev) · [Defuddle](https://github.com/kepano/defuddle)

## License

[MIT](LICENSE)
