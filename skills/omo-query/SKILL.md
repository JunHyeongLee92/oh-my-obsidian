---
name: omo-query
description: Search the user's oh-my-obsidian vault for an answer and synthesize a response from wiki pages. Starts from wiki/index.md, follows [[wikilinks]], falls back to qmd hybrid search (BM25 + semantic) if the index doesn't resolve. Auto-promotes reusable answers into new wiki pages. Use when the user says "/omo-query <keyword>", "search the vault", "find X in the wiki", "what was the Y we wrote up before", "위키에서 X 찾아줘", "이전에 정리한 Y 뭐였지", "vault에서 검색".
origin: oh-my-obsidian
---

# omo-query — Wiki Search + Auto-Promote

Locate the relevant pages in the vault and synthesize an answer from the collected content. If the answer has reusable value, **the LLM decides directly** to promote it into a new wiki page — it does not ask the user.

## When to activate

- `/omo-query <term>`
- "find X in the wiki", "do we have Y in our vault?", "what did we say about Z before"
- "위키에서 X 찾아", "우리 위키에 Y 있어?", "전에 정리한 Z"
- Any question about a topic likely covered in a prior session

## Procedure

### 1. Resolve vault path

```bash
VAULT=$(node -e "process.stdout.write(require(process.env.HOME+'/.config/oh-my-obsidian/config.json').vaultPath)")
```

### 2. Index-first

Read `$VAULT/wiki/index.md` first. If a relevant category (Projects / Entities / Concepts / Guides / Summaries / Digests) identifies a candidate page, read that file directly.

### 3. Follow wikilinks

Traverse the `[[wikilinks]]` on the pages you've read to find related material. Stop at depth 3.

### 4. Fallback: qmd hybrid search

If the index alone cannot produce an answer:

```bash
cd "$VAULT" && qmd query "<keyword>" --limit 10
```

(`qmd` searches markdown files via BM25 + semantic + reranking. It only works when an index exists at `$VAULT`.)

If `qmd` is not installed, fall back to the Grep tool to keyword-search the whole vault.

### 5. Synthesize the answer

Assemble the answer from the gathered pages. Cite each page inline with a `[[wikilink]]`, and list them under "References" at the end.

### 6. Auto-promote decision (LLM-first)

Decide **immediately, without asking**, whether the answer is worth preserving as a wiki page.

**Promote when any of these hold**:

- The answer contains a **new insight or synthesis** not present in any existing page.
- It is the result of **comparing/structuring** content across multiple pages.
- It carries a **reusable abstraction** that would help the next time the same question comes up.

**Do not promote when**:

- The answer is essentially a lookup that duplicates an existing page.
- It is a one-shot answer valid only at a specific moment (e.g. "what's the current status?").
- Updating an existing page is more appropriate (in that case, update it and report).

After deciding, report the **action you have already taken**:

> "Promoted this answer into `wiki/concepts/<slug>.md`. Reason: new abstraction synthesized from X / Y / Z pages."

or:

> "Not promoted. Reason: [[existing-page]] already covers this."

If the user disagrees, they can override **after the fact** ("delete that page", "didn't need promotion", etc.).

### Content language

The answer synthesis shown to the user and any promoted page content (section headers + body prose) follow the **user's working language** — the language the user asked the question in. A Korean question gets a Korean answer and, if promoted, a Korean page with headers like `## 정의 / ## 설명`; an English question gets English throughout.

**Stays English regardless** (schema anchors): frontmatter keys, `page-types.md` enum values (`concept`, `entity`, etc.), wikilink targets/slugs, `wiki/log.md` action column (`promoted`).

### 7. Promotion execution

- Create the new page with the appropriate page type (see `page-types.md`).
- Register it in the matching section of `wiki/index.md`.
- Append a `promoted` entry to `wiki/log.md`:
  ```
  | YYYY-MM-DD | promoted | [[<slug>]] | /omo-query synthesis: brief of the original query |
  ```

## References

- `<plugin>/schema/wiki-rules.md` — Query action flow
- `<plugin>/schema/page-types.md` — per-type sections for the promoted page

## Anti-patterns

- Asking the user whether to promote (by design, the LLM decides, executes, and reports).
- Promoting every answer without judging reusability (creates noise).
- Creating a page without frontmatter or cross-links.
- Answering from web search alone without consulting the vault (this skill is for vault-internal answers only).
