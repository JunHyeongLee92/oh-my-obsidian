---
type: schema
created: 2026-04-06
updated: 2026-04-06
---

# Lint Rules

Rules that check the vault's health. Run automatically by the plugin's `scripts/lint.sh`.

## Checks

### 1. Orphan pages (orphan-pages)

- **Severity**: WARN
- **Rule**: Every wiki page must be linked from at least one other wiki page via `[[link]]`.
- **Exceptions**: `wiki/index.md`, `wiki/log.md`.
- **Fix**: Find a relevant page and add the link.

### 2. Missing cross-references (missing-crossrefs)

- **Severity**: INFO
- **Rule**: Every wiki page must have at least two outgoing `[[link]]`s.
- **Exception**: Worklog pages pass with one (the project index link).
- **Fix**: Find related entity/concept pages and add links.

### 3. Stale claims (stale-claims)

- **Severity**: WARN
- **Rule**: Flag any page whose frontmatter `updated` is older than 90 days.
- **Exception**: Pages with `status: archived` are skipped.
- **Fix**: Review the content. If it is still valid, bump `updated`; otherwise edit it or set `status: archived`.

### 4. Frontmatter validation (frontmatter-validation)

- **Severity**: CRITICAL
- **Rule**: Every wiki page must include the required fields defined in `frontmatter-spec.md`.
- **Items checked**:
  - `type` present and a valid value
  - `created` present and in `YYYY-MM-DD`
  - `updated` present and in `YYYY-MM-DD`
  - `status` present and a valid value
  - Per-type required fields present

### 5. Index sync (index-sync)

- **Severity**: WARN
- **Rule**: Every page under `wiki/` (excluding `index.md`, `log.md`, worklog) must be registered in `wiki/index.md`.
- **Fix**: Add the missing page to `index.md`.

### 6. Dead links (dead-links)

- **Severity**: CRITICAL
- **Rule**: Every `[[wiki-link]]` must resolve to an existing file.
- **Fix**: Create the target page, or fix/remove the link.

### 7. Empty pages (empty-pages)

- **Severity**: WARN
- **Rule**: Flag pages that contain only frontmatter and no body.
- **Fix**: Write the body or delete the page.

### 8. Naming convention (naming-convention)

- **Severity**: INFO
- **Rule**: See [`wiki-rules.md#file-naming`](wiki-rules.md#file-naming).
- **Implementation**: plugin `scripts/lint-checks/naming-convention.sh`.

### 9. Unescaped pipe wikilinks in tables (table-wikilink-pipe)

- **Severity**: WARN
- **Rule**: A wikilink with an alias pipe (`[[path|alias]]`) inside a markdown table row collides with the column delimiter and breaks rendering. Escape the pipe as `\|` or use the alias-free form.
- **Implementation**: plugin `scripts/lint-checks/table-wikilink-pipe.sh`.

## Severity levels

| Severity | Meaning                          | Action                              |
|----------|----------------------------------|-------------------------------------|
| CRITICAL | Vault integrity at risk          | Fix immediately in the next session |
| WARN     | Vault quality degrading          | Fix as soon as practical            |
| INFO     | Improvement suggestion           | Fix when convenient                 |
