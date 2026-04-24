---
type: schema
created: 2026-04-06
updated: 2026-04-20
---

# Wiki Rules

This document is the master rulebook an LLM follows when operating this vault.

## Architecture: three layers

### Layer 1: `_sources/` (original material)

- Immutable. Once stored, an original file is never modified.
- Subcategories: `projects/`, `papers/`, `articles/`, `conversations/`, `assets/`, `misc/`.
- Every source file must carry frontmatter metadata (title, source-type, source-url, ingested-date).
- **Only external originals go here.** Artifacts produced by an LLM or a human (slides, build output, reports, …) live outside the vault.

### Layer 2: `wiki/` (LLM-maintained wiki)

- All knowledge lives inside `wiki/` as interconnected markdown pages.
- Page types: projects, worklog, decisions, jira, entities, concepts, guides, summaries, digests.
- Every page must have a valid YAML frontmatter (see `frontmatter-spec.md`).
- Every page must link to at least one other wiki page via `[[wikilinks]]`.
- Every claim must be grounded in a source, with the origin surfaced as a link to a `[[summary-page]]`.

### Layer 3: plugin `schema/` (the layer this document belongs to)

- Defines the rules by which the LLM operates the wiki.
- Infrastructure, not content. Not a wiki page.
- Lives outside the vault (inside the plugin) → multiple vaults can share the same ruleset.

## Paths per page type

| type        | path                                               |
|-------------|----------------------------------------------------|
| project     | `projects/{name}/index.md`                         |
| project-doc | `projects/{name}/docs/{architecture,usage}.md`     |
| worklog     | `projects/{name}/worklog/YYYY-MM-DD.md`            |
| decision    | `projects/{name}/decisions/dec-NNN-*.md`           |
| jira        | `projects/{name}/jira/piaxt-NNN.md`                |
| entity      | `wiki/entities/*.md`                               |
| concept     | `wiki/concepts/*.md`                               |
| guide       | `wiki/guides/*.md`                                 |
| summary     | `wiki/summaries/*.md`                              |
| digest      | `wiki/digests/YYYY-WNN.md`                         |

## Four actions

### 1. Ingest (collecting a source)

1. Extract the original with the plugin's `scripts/clip.sh <URL> [category]` and save it under `_sources/{category}/` (Defuddle-based, no AI processing).
2. Read the stored source and extract the core entities, concepts, and procedures.
3. Create or update wiki pages based on what was extracted:
   - **Entities** (tools, people, services, …) → `wiki/entities/`
   - **Concepts** (patterns, methodologies, technical ideas, …) → `wiki/concepts/`
   - **Procedures** (install guides, usage walkthroughs, troubleshooting, …) → `wiki/guides/`
5. Create a summary page under `wiki/summaries/` (one summary per source).
6. Register the new pages in `wiki/index.md`.
7. Append an entry to `wiki/log.md`.

### 2. Query

1. The user asks to find something in the wiki.
2. Read `wiki/index.md` first to locate the relevant categories and pages.
3. If `index.md` identifies a specific page, read that file directly. If not, run `qmd query` (keyword + similarity + rerank).
4. Read the identified or returned documents and follow their `[[wikilinks]]` to gather related material.
5. Synthesize the answer from the collected wiki content.
6. If the answer has reusable value, promote it into a new wiki page.
7. When promoting, append a `promoted` entry to `wiki/log.md`.

### Log action values

Allowed values for the action column in `wiki/log.md`:

- `ingest` — collection of an external source (URL, etc.)
- `create` — new page creation (not ingest or promotion)
- `update` — page modification
- `delete` — page deletion
- `lint` — lint-run log
- `promoted` — content created mid-conversation permanentized as a wiki page. Put the originating skill in the description column (e.g. "synthesized by /omo-query", "`/omo-study` learning session")
- `analyze` — project-understanding doc refresh under `projects/<name>/docs/` (emitted by `/omo-project-analyze`). Distinct from `update` because it represents a full repo-snapshot refresh with a `source-commit` baseline, not an incremental edit.

### 3. Lint

1. Cron runs it automatically every day at 03:00 (plugin `scripts/lint.sh`).
2. Checks: see `lint-rules.md`.
3. Output is written to `_ops/lint-reports/latest.md`.
4. CRITICAL issues must be fixed in the next session immediately.

### 4. Weekly Digest

1. Cron runs it automatically every Monday at 03:30 (plugin `scripts/weekly-digest.sh`).
2. Pull this week's added/changed wiki pages from `wiki/log.md`.
3. Cross-domain analysis: surface insights that connect materials from different fields.
4. Write the result to `wiki/digests/YYYY-WNN.md` (e.g. `2026-W14.md`).
5. Register it in `wiki/index.md` and append to `wiki/log.md`.

## Project management

Projects live under `projects/{name}/`.

- `index.md`: project overview + current state. Keep it current every session — it doubles as the context hand-off to the next session. **One-page hub for summary only; move detailed content into `docs/`.**
- `docs/`: (optional) **static understanding documents** that an LLM generates by analyzing the repo. Typical contents: `architecture.md` + `usage.md`. If `index.md` is the "at-a-glance" hub, `docs/*` holds "deep, session-to-session reusable understanding". Generated and refreshed by the `/omo-project-analyze` skill; the frontmatter `source-commit` field preserves the snapshot point.
- `worklog/`: daily work logs. Include plan, completed items, pending items, changed files, and commit hashes.
- `decisions/`: decision records. Preserve "why we chose B over A".
- `jira/`: (optional) per-ticket report content. Create only for projects that track Jira tickets.

**Four axes**:
- `index.md` = hub · `docs/` = static understanding · `worklog/` = time · `decisions/` = decisions

## Diagrams

- Prefer **Mermaid** over ASCII art when visualizing structure or relationships.
- Styling: see `mermaid-style.md`.

## Obsidian syntax

- Every page must render correctly in Obsidian's Reading View.
- For syntax reference (wikilinks, embeds, callouts, block references, highlights, …) and recommended syntax per page type, see `obsidian-syntax.md`.

## Page conventions

### File naming
- Use kebab-case (e.g. `llm-wiki.md`, `dec-001-db-choice.md`).
- Do not put dates in filenames (dates belong in frontmatter). Worklog is the only exception (`2026-04-06.md`).

### Page language
- The body follows the user's working language. For a public open-source vault the default is English; a personal or team vault may use Korean or any other language consistently.
- Regardless of language, technical terms, code, and product names stay in English (e.g. LangGraph, Next.js, API).

### Links
- When an entity or concept is mentioned, and a wiki page for it exists, always use a `[[wiki-link]]`.
- **Project links include the path**: `[[vibevoice/index|vibevoice]]` (because the project's landing page is `index.md`).
- When creating a new page, find existing pages that mention the topic and add back-links.
- Prefer explicit links over tags.

### Cross-references
- If two pages mention the same entity/concept but do not link to each other, lint flags it.
- Every wiki page must link to at least one other wiki page.

### New page vs. update existing
- If a page for the topic already exists → update it.
- If it does not exist and the topic is self-contained → create a new page.
- If unsure → add a section to the existing page first, and split it out when it grows too large.

### Migration exception
- When migrating data from a previous system (PARA, etc.) into the wiki, skip the ingest process.
- Do not create anything under `_sources/` or `wiki/summaries/`; write the wiki pages directly.
- Still obey the rest: registering in `index.md`, appending to `log.md`, frontmatter requirements, and cross-reference conventions.
