# Plugin concepts

**English** · [한국어](concepts.ko.md)

How the OMO plugin works internally — architecture, search path, vault structure.

## Background

OMO implements the pattern Andrej Karpathy describes in his [LLM wiki gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f): instead of having an LLM rediscover knowledge from raw documents on every query (traditional RAG), the LLM maintains a persistent markdown wiki that compiles knowledge once during ingestion and keeps it current through structured updates. Three layers make this work:

- **`_sources/`** — immutable raw material (articles, papers, conversations). Written once on ingest, never mutated.
- **`wiki/`** — the LLM-curated knowledge layer. Typed pages (entities, concepts, guides, summaries, digests) with schema-checked frontmatter and cross-links, so an agent can traverse the graph instead of re-reading sources.
- **`schema/`** — the conventions document that tells the LLM how to shape pages (`page-types.md`, `frontmatter-spec.md`, `lint-rules.md`, etc.).

The wiki is a "compounding artifact" — every ingest adds cross-references, every digest surfaces cross-domain patterns, and every answered question with reusable value can be promoted into a new page so the next session doesn't re-derive it from scratch.

## Architecture

Multiple git projects connect to a **single Obsidian vault** used as a central knowledge hub. The plugin (harness) orchestrates user commands, automation, and hooks; the user does not manage the vault directly.

![oh-my-obsidian architecture](architecture.png)

**How to read it**:

- **Purple focal points** — Skills (orchestration entry points) and `wiki/` (the knowledge hub). The two centers of the system.
- **Solid lines** — active actions such as user commands and internal reads/writes.
- **Dashed lines** — automated events (URL fetch, cron schedules, commit triggers, staleness warnings).
- N projects share **one vault**. Each project keeps its own scratchpad under `projects/<name>/` (sibling to `wiki/`, not inside it), and the project's `CLAUDE.md` back-references the vault.

See [CONTRIBUTING.md § Architecture](../CONTRIBUTING.md#architecture) for design principles.

## Search behavior

`/omo-query` uses a three-tier fallback:

1. **Wiki-structure (primary)** — select candidate pages from the `wiki/index.md` category index → read directly → traverse `[[wikilinks]]` up to 3 depth.
2. **`qmd` hybrid search (fallback)** — if Tier 1 cannot synthesize an answer, call `qmd query`. Combines BM25 (keyword) + semantic (embedding) + re-ranking.
3. **Grep full scan (last resort)** — backup for environments without `qmd` installed.

When the wiki structure (index + wikilinks) is well-maintained, Tier 1 resolves the query and `qmd` is never invoked. A cron job refreshes the `qmd` index daily at 03:15 as insurance.

**Two kinds of indexes**:

| Index               | Medium                              | Refresh cadence                     | Role                    |
| ------------------- | ----------------------------------- | ----------------------------------- | ----------------------- |
| `wiki/index.md`     | Human-readable markdown + wikilinks | **Immediate** on every write skill  | Primary traversal (T1)  |
| `qmd` hybrid        | External BM25 + semantic embeddings | Cron, once daily (03:15)            | Fallback search (T2)    |

## Vault layout

```
~/my-vault/
├── wiki/                    # LLM-maintained knowledge (derived from _sources/)
│   ├── index.md             #   Category index (03:15 daily refresh)
│   ├── log.md               #   Append-only change history
│   ├── entities/            #   People, tools, services, products, organizations
│   ├── concepts/            #   Patterns, methodologies, technical ideas
│   ├── guides/              #   How-to guides
│   ├── summaries/           #   One summary per source (ingest output)
│   └── digests/             #   Weekly re-synthesis (Monday 03:30)
├── projects/                # User/LLM collaborative workspace (per linked repo)
│   └── <name>/
│       ├── index.md         #   1-page hub — current state at-a-glance
│       ├── docs/            #   Static understanding (architecture.md, usage.md)
│       ├── worklog/         #   Time-axis records (YYYY-MM-DD.md)
│       └── decisions/       #   ADRs (dec-NNN-*.md)
├── _sources/                # External originals (immutable)
│   └── articles/ papers/ conversations/ assets/ misc/
├── _ops/
│   ├── lint-reports/        #   Lint output (only per-host latest-<hostname>.md tracked in git)
│   └── templates/           #   10 Obsidian Templater templates (manual page creation)
├── .obsidian/               # Obsidian settings (templates pre-wired)
├── README.md                # Vault user guide (auto-generated)
└── .gitignore
```

## Cron schedule

Jobs registered automatically by `/omo-init` (tagged `OMO-CRON` — recognized by `omo-uninstall`):

- **Daily 03:00** — `lint.sh` (schema-violation detection, report only)
- **Daily 03:15** — `qmd-update.sh` (refresh the `qmd` hybrid index used as search fallback)
- **Monday 03:30** — `weekly-digest.sh` (weekly re-synthesis via the Claude CLI)

`git-sync` is **not** auto-registered — fresh vaults typically lack remotes / SSH auth, so sync would only keep failing. For manual registration after wiring a remote, see [git-sync.md](git-sync.md).
