---
name: omo-ingest
description: Ingest a URL into the user's Obsidian vault as an LLM wiki entry. Runs clip.sh to extract clean markdown into _sources/, then creates a summary page plus entity / concept / guide pages per the vault schema, registers them in wiki/index.md, and appends to wiki/log.md. Use when the user says things like "/omo-ingest <URL>", "add this URL to the wiki", "save this article", "capture this", "이 URL 위키에 추가", "이거 기록해줘", "위키에 저장해줘", "이 아티클 정리해서 위키에 넣어줘".
origin: oh-my-obsidian
---

# omo-ingest — URL → LLM Wiki

Take an external URL and produce both an immutable original in the vault and structured wiki pages derived from it.

## When to activate

- `/omo-ingest <URL>`
- User pairs a URL with phrases like "add to the wiki", "capture this", "save this"
- User points at an open tab or a URL in the conversation and says "save this"

## Inputs

- **URL** (required)
- **category** (optional): `articles | papers | conversations | misc`. If omitted, **the LLM infers it from the URL, title, and body** — do not ask the user. Include the inference reason in the final report as a one-liner.
- **filename** (optional): auto-generated from the title if not provided

**Category inference hints**:

- `articles` — blog posts, READMEs, news, generic web articles (default fallback)
- `papers` — arxiv / acm / ieee / academic journal domains, PDF-format papers
- `conversations` — ChatGPT share links, Discord/Slack threads, forum Q&A
- `misc` — anything that doesn't fit the above

## Procedure

### 1. Resolve paths

```bash
CONFIG=~/.config/oh-my-obsidian/config.json
VAULT=$(node -e "process.stdout.write(require('$CONFIG').vaultPath)")
PLUGIN=$(node -e "process.stdout.write(require('$CONFIG').pluginRoot || process.env.HOME+'/.claude/plugins/marketplaces/oh-my-obsidian')")
```

### 2. Load schema context

Before doing anything else, **read the schema files with the Read tool**:

- `$PLUGIN/schema/wiki-rules.md` — the "Ingest" procedure among the four actions
- `$PLUGIN/schema/page-types.md` — required sections for Summary / Entity / Concept / Guide
- `$PLUGIN/schema/frontmatter-spec.md` — frontmatter schema
- `$PLUGIN/schema/obsidian-syntax.md` — recommended callout / highlight / embed syntax

Writing pages without loading the schema will trigger CRITICAL lint issues.

### 3. Run clip.sh to extract the source

```bash
bash "$PLUGIN/scripts/clip.sh" "<URL>" "<category>" [<filename>]
```

Output: `$VAULT/_sources/<category>/<filename>.md` (immutable — never modify afterwards).

### 4. Read the extracted source

Use the Read tool on the freshly stored file to grasp the title, body, and key points.

### Content language

Generated wiki pages (summaries, entities, concepts, guides) — both section headers and body prose — follow the **user's working language**. A Korean user's vault gets `## 정의 / ## 설명 / ## 관련 개념`; an English vault gets `## Definition / ## Explanation / ## Related concepts`. Match existing vault pages when present.

**Stays English regardless** (schema anchors): frontmatter keys (`type`, `source-type`, `source-url`, `ingested-date`, `tags`, etc.), enum values (`summary`, `entity`, `concept`, `guide`, `article|paper|conversation|misc`), wikilink targets/slugs, and `wiki/log.md` action column (`ingest`).

### 5. Extract entities, concepts, guides

Identify from the body:

- **Entities** (tools / people / services / products): check `$VAULT/wiki/entities/` first — create if missing, update if present
- **Concepts** (patterns / methodologies / technical ideas): `$VAULT/wiki/concepts/`
- **Procedures** (install guides, usage guides, troubleshooting): `$VAULT/wiki/guides/`

When unsure, prefer adding a section to an existing page and split later once it grows.

### 6. Create the summary page

`$VAULT/wiki/summaries/<slug>.md` — one summary per source. Must include every required section defined in `page-types.md` § Summary:

- Source info (title, author, URL, type, date)
- Key takeaways
- Extracted entities (as wikilinks)
- Extracted concepts (as wikilinks)

Frontmatter fields (see `frontmatter-spec.md` § Summary):
```yaml
type: summary
source-path: "_sources/<category>/<filename>.md"
source-type: article | paper | conversation | misc
source-url: "<URL>"
ingested-date: YYYY-MM-DD
```

### 7. Register in index and log

- Add links to the new pages into the matching section of `$VAULT/wiki/index.md` (Entities / Concepts / Guides / Summaries). Bump the frontmatter `updated`.
- Append an `ingest` row to `$VAULT/wiki/log.md` (newest at the top):
  ```markdown
  | YYYY-MM-DD | ingest | [[<slug>]] | one-line summary |
  ```

### 8. Back-links

If the new page mentions an existing page, add a back-link from the existing page as well (wiki-rules "Cross-references").

### 9. Report to the user

Short report: list of created/updated files, the rationale for the classification (why this entity / concept bucket), and any suggested follow-ups (e.g. related concepts to flesh out).

## Anti-patterns

- Modifying originals under `_sources/` (strictly forbidden)
- Creating a page without frontmatter
- Creating an isolated page with no outbound links (wiki-rules requires at least one)
- Two pages on the same topic — creating a duplicate without checking existing pages first

## Safety

- Always read the schema files first (they may have been updated).
- Escalate to the user when a change doesn't fit the wiki structure.
