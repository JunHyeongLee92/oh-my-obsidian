---
name: omo-digest
description: Generate a weekly digest page for the user's Obsidian vault. Aggregates wiki/log.md entries from the past week, surfaces cross-domain insights between unrelated sources, and writes wiki/digests/YYYY-WNN.md following the Digest Page schema. Normally runs as cron every Monday 03:30 but can also be invoked manually. Use when the user says "/omo-digest", "run the weekly digest", "cut this week's digest", "주간 재가공해줘", "이번주 digest", or when a week has passed without a digest.
origin: oh-my-obsidian
---

# omo-digest — Weekly Re-processing

Analyze the week's wiki changes, surface cross-domain insights, and write the digest page. Handling of an existing file is **rule-based** — do not ask the user.

## When to activate

- `/omo-digest`
- "run the weekly digest", "cut this week's digest"
- "주간 재가공", "이번주 digest"
- Runs automatically every Monday at 03:30 via cron (which invokes the Claude CLI directly)

## Procedure

### 1. Resolve paths and dates

```bash
CONFIG=~/.config/oh-my-obsidian/config.json
VAULT=$(node -e "process.stdout.write(require('$CONFIG').vaultPath)")
YEAR_WEEK=$(date +%Y-W%V)
MONDAY=$(date -d "last monday" +%Y-%m-%d 2>/dev/null || date -d "monday - 7 days" +%Y-%m-%d)
TODAY=$(date +%Y-%m-%d)
DIGEST_FILE="$VAULT/wiki/digests/$YEAR_WEEK.md"
```

### 2. Existing-digest handling (LLM-first, rule-based)

When `$DIGEST_FILE` already exists, decide **without asking**:

| Situation                                                                  | Action                                      | Reason                           |
|----------------------------------------------------------------------------|---------------------------------------------|----------------------------------|
| Cron-driven run                                                            | Skip + exit 0                               | Prevent duplicate generation     |
| Manual run + user explicitly says "regenerate" / "refresh" / "overwrite"   | Overwrite (git preserves the previous copy) | Explicit request                 |
| Manual run without an explicit override                                    | Skip + report "already exists"              | No need to regenerate the same week |

To check whether the existing file **was edited by the user**, use `git log` or inspect the file for hand-edited traces. If any edit trace is found, always Skip + report.

```bash
if [ -f "$DIGEST_FILE" ]; then
  # Rule-based decision — no prompt
  echo "This week's digest already exists: $DIGEST_FILE"
  exit 0
fi
```

### 3. Load schema for the Digest Page

Read:
- `<plugin>/schema/wiki-rules.md` — the 4th action "Weekly Digest"
- `<plugin>/schema/page-types.md` — the "Digest Page" required sections
- `<plugin>/schema/frontmatter-spec.md` — Digest fields (`week: YYYY-WNN`)

### 4. Gather this week's changes

Read `$VAULT/wiki/log.md` and collect entries in the `$MONDAY ~ $TODAY` range. Classify the changed pages by title and type:

- New entities
- New concepts
- New guides
- New summaries
- Project worklog / decisions

### 5. Cross-domain analysis

Look for insights that connect material from **different domains** within the same week. For example:

- Does an entity ingested this week bear on an open problem in an existing project?
- Do sources from different fields mention the same pattern?
- Does a new concept invite reevaluation of an existing decision?

This is where the digest earns its keep — do not stop at a "here's what happened this week" recap.

### Content language

The digest page's section headers and body prose follow the **user's working language** — for cron-triggered runs, match the dominant language of recent `wiki/log.md` entries and existing digest pages. A Korean vault gets `## 이번 주 변경사항 / ## 도메인 횡단 분석 / ## 다음 주 주목`; an English vault gets `## Weekly changes / ## Cross-domain analysis / ## To watch next week`.

**Stays English regardless** (schema anchors): frontmatter keys (`type`, `week`, `created`, `updated`, `status`), `page-types.md` enum value `digest`, wikilink targets, week slug format `YYYY-WNN`, `wiki/log.md` action column (`create`).

### 6. Write the digest page

Follow the Digest section structure from `page-types.md`:

- **Weekly changes** — list of added/changed pages + a one-line summary each
- **Cross-domain analysis** — 2–5 insights (each with supporting `[[wikilinks]]`)
- **To watch next week** — follow-up topics worth exploring

Frontmatter:
```yaml
---
type: digest
created: <TODAY>
updated: <TODAY>
status: active
week: <YEAR_WEEK>
---
```

### 7. Register and log

- Add `[[<YEAR_WEEK>]]` under the `## Digests` section of `$VAULT/wiki/index.md`
- Append a row to `$VAULT/wiki/log.md`:
  ```
  | YYYY-MM-DD | create | [[<YEAR_WEEK>]] | weekly digest (<MONDAY> ~ <TODAY>) |
  ```

### 8. Report to the user

Short report with the output path and 2–3 key insights.

If you overwrote an existing digest, add a short "what changed" note (based on the git diff).

## Cron-driven path

When run via cron, `<plugin>/scripts/weekly-digest.sh` invokes the Claude CLI (`claude -p ...`) to execute this skill non-interactively. In a cron context there is no user present, so **always follow the LLM rules** (Skip if the file already exists).

## References

- Script: `<plugin>/scripts/weekly-digest.sh`
- Schema: `<plugin>/schema/wiki-rules.md`, `page-types.md`

## Anti-patterns

- Asking "overwrite?" when the file exists (violates the LLM-first principle — decide by rule).
- A flat "what happened this week" recap with no cross-domain analysis.
- Overwriting an existing digest without an explicit user override (default is skip).
- Mentioning other pages in the digest as plain text instead of `[[wikilinks]]`.
