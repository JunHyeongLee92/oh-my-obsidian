---
name: omo-lint
description: Run schema and consistency checks against the user's Obsidian vault via lint.sh. Reports CRITICAL, WARN, INFO counts and writes a timestamped report plus a per-host latest report. Proposes fixes for CRITICAL issues and asks user confirmation before modifying files. Use when the user says "/omo-lint", "run vault lint", "check the wiki", "위키 점검해줘", "vault lint", or right after the agent has made bulk wiki edits and wants to verify no schema violations.
origin: oh-my-obsidian
allowed-tools: Bash, Read, Edit, Write, AskUserQuestion
---

# omo-lint — Vault Schema Check

Check the vault for schema / link / frontmatter consistency. When CRITICAL issues exist, **present the fix plan first and only apply it after explicit user confirmation** — touching existing files must stay visible to the user.

## When to activate

- `/omo-lint`
- "run lint on the vault", "check wiki integrity"
- "위키 점검", "lint 돌려줘"
- Right after you (the agent) made bulk wiki edits and want to verify no schema violations

## Procedure

### 1. Resolve paths

```bash
CONFIG=~/.config/oh-my-obsidian/config.json
PLUGIN=$(node -e "process.stdout.write(require('$CONFIG').pluginRoot || process.env.HOME+'/.claude/plugins/marketplaces/oh-my-obsidian')")
VAULT=$(node -e "process.stdout.write(require('$CONFIG').vaultPath)")
```

### 2. Run lint.sh

```bash
bash "$PLUGIN/scripts/lint.sh"
```

Output reports:
- `$VAULT/_ops/lint-reports/lint-<timestamp>.md` — this run
- `$VAULT/_ops/lint-reports/latest-<hostname>.md` — latest per host

Exit codes:
- `0` — no CRITICAL
- non-zero — CRITICAL present

### 3. Summarize the results

Read the report and **show the user first**:

```
Lint result
- CRITICAL: N
- WARN: N
- INFO: N

CRITICAL details:
- wiki/<path1>.md — <issue>
  Proposed fix: <what / how>
- wiki/<path2>.md — <issue>
  Proposed fix: <what / how>

Top 3 WARN:
- ...
```

For each CRITICAL:
1. Cross-check the rule against `<plugin>/schema/lint-rules.md`
2. Read the affected file and draft a **concrete fix plan** (which line to change and how)
3. Include the plan in the report

### Content language

The summary shown to the user + any narrative around CRITICAL fixes follows the **user's working language**. The underlying `lint.sh` machine-output report (`_ops/lint-reports/lint-<timestamp>.md`) is English-only by design (schema-aligned report file, not user narrative).

### 4. Ask user confirmation (AskUserQuestion)

Invoke only when CRITICAL issues exist:

**Question**:
- header: `Apply fixes`
- question: "Apply the proposed fixes for the N CRITICAL issues above?"
- multiSelect: false
- options:
  - label: `Apply all fixes` / description: "Apply every proposed fix (recommended)"
  - label: `Skip` / description: "Do nothing; let the user handle it later"

(Per-file selection via multiSelect is possible if needed, but default is all-or-skip.)

### 5. Apply fixes (when confirmed)

If `Apply all fixes`:

1. Apply the fixes to each CRITICAL file via Edit/Write
2. Re-run `lint.sh` and confirm CRITICAL = 0
3. If after two attempts CRITICAL remains, report it with the reason

If `Skip`:

- Do not modify anything; report "left as-is"
- Share the report file path so the user can handle it manually

### 6. WARN / INFO handling

**Do not auto-fix** — these involve judgment; report only.

- Summary of top 3 WARN + one-line suggestion each
- INFO: just the count

If the user later asks "fix the WARN items too", run the same loop (summary → confirmation → fix).

### 7. Final report

If CRITICAL = 0, keep it concise:

> "Lint passed. CRITICAL=0 WARN=N INFO=N."

If fixes were applied:

```
Lint fixes applied.
- CRITICAL: N → 0
- Files modified:
  - wiki/<path>.md: <what / why>
  - ...
```

## Lint checks (summary)

The 9 checks under `<plugin>/scripts/lint-checks/`:

- `dead-links` — detect non-existent `[[link]]` (CRITICAL). Ignores inside backticks / fences.
- `empty-pages` — pages with no body (WARN)
- `frontmatter-validation` — missing required fields (CRITICAL)
- `index-sync` — missing entry in `index.md` (WARN)
- `missing-crossrefs` — too few outgoing `[[link]]`s per page (INFO)
- `naming-convention` — not kebab-case (INFO)
- `orphan-pages` — no page links to this page (WARN)
- `stale-claims` — stale-page candidates (INFO)
- `table-wikilink-pipe` — unescaped `|` in wikilinks inside tables (CRITICAL)

Exact definitions: `<plugin>/schema/lint-rules.md`.

## Anti-patterns

- Applying CRITICAL fixes **without confirmation** (modifications to existing files must stay visible — a wrong auto-fix can corrupt data)
- Dismissing CRITICAL as "not a big deal" and skipping
- Hand-editing the report to make it look like it "passed"
- Auto-fixing WARN/INFO (judgment required — only on explicit user request)
- Silently ignoring a failed fix (report the failure explicitly)
