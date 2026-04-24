# Contributing to oh-my-obsidian

OMO is a Claude Code plugin, so the contribution flow differs slightly from a typical library. The notes below are a practical guide for teammates and external contributors changing or adding skills, scripts, or schemas.

## Architecture

### Design principles

1. **Plugin = rules + scripts + schema** — the plugin side is user- and machine-independent. It must behave identically wherever it is installed.
2. **Vault = data only** — `wiki/` and `_sources/` contain pure data. A plugin version bump must not break existing vaults.
3. **Config SSOT** — `~/.config/oh-my-obsidian/config.json` is the single source of truth for the vault path. All scripts and skills resolve paths through this file.
4. **No absolute paths hardcoded** — all internal paths resolve via config or env. The only exception is cron lines (cron does not support relative paths).

These four principles are **design-review tripwires**: any contribution that crosses them (e.g. adding an executable script into the vault, or hardcoding `/home/<user>/...` inside a script) must be reviewed.

### Repo layout

```
oh-my-obsidian/
├── .claude-plugin/        # plugin + marketplace manifests
├── skills/                # 10 Claude Code skills (omo-init, omo-ingest, omo-query,
│                          #   omo-project-add, omo-project-analyze, omo-project-update,
│                          #   omo-study, omo-lint, omo-digest, omo-uninstall)
├── scripts/               # clip, lint, digest, git-sync, qmd-update, install-cron,
│                          #   uninstall-cron + lib/ + lint-checks/
├── schema/                # wiki rules, page types, frontmatter spec, lint rules,
│                          #   mermaid style, obsidian syntax
├── hooks/                 # plugin-native hooks (hooks.json + wiki-staleness-check.sh)
├── templates/             # initial vault structure copied by /omo-init
│   ├── wiki/, _sources/, _ops/lint-reports/
│   ├── _ops/templates/    # 10 Obsidian Templater templates for manual page creation
│   └── .obsidian/         # Obsidian app core-plugin config scaffold
└── docs/                  # troubleshooting.md, git-sync.md, concepts.md (public)
```

When you add a new skill, add only `skills/omo-<name>/SKILL.md`. A new lint check requires a pair — `schema/lint-rules.md` plus `scripts/lint-checks/<name>.sh` (see §2, §3).

## Local development loop

Once installed from a marketplace, the plugin is pinned at `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`. To reflect local edits immediately:

**Option A — symlink the repo into the plugin path (recommended)**

```bash
# Remove the cached copy
rm -rf ~/.claude/plugins/cache/oh-my-obsidian

# Link your working repo
ln -s ~/workspace/oh-my-obsidian ~/.claude/plugins/local/oh-my-obsidian

# Reload in Claude Code
/reload-plugins
```

**Option B — use the `CLAUDE_PLUGIN_ROOT` env var**

```bash
export CLAUDE_PLUGIN_ROOT=~/workspace/oh-my-obsidian
```

Run `/reload-plugins` after changes. Skill markdown takes effect immediately; bash scripts apply from the next invocation.

## Contribution guides by type

### 1. Add a new skill

1. Create `skills/omo-<name>/SKILL.md`.
2. Required YAML frontmatter fields:
   ```yaml
   ---
   name: omo-<name>
   description: <one English sentence + Korean natural-language trigger examples>
   origin: oh-my-obsidian
   ---
   ```
3. `description` is **the only cue for intent matching**. Include natural-language trigger examples in `description` (e.g. "add this to the wiki", "/omo-<name>").
4. Recommended section order: `When to activate` → `Inputs` → `Steps` → `Output` → `Notes`.
5. If the new skill overlaps with an existing one, consider consolidating (you should be able to state a concrete added-value line in the README "Skills" table).
6. Update the Skills table in `README.md` / `README.ko.md` and the "usage" section in `templates/README.md`.

### 2. Change the schema

When editing the six files under `schema/` — `wiki-rules` · `page-types` · `frontmatter-spec` · `lint-rules` · `mermaid-style` · `obsidian-syntax` — follow:

| Change type   | Example                                                           | Version bump        |
|---------------|-------------------------------------------------------------------|---------------------|
| **Additive**  | Add a new field or page type; existing data still valid           | Patch (`0.0.X`)     |
| **Breaking**  | Make an existing field required, drop a page type, change format  | Minor (`0.X.0`)     |

Breaking changes **must include a migration note in CHANGELOG** — describe the manual migration path so existing vaults that trip the new lint have a way forward.

When you add a check to `lint-rules.md`, ship the matching implementation in `scripts/lint-checks/<name>.sh`.

### 3. Modify scripts

- All scripts resolve paths through `scripts/lib/config.sh` helpers `omo_get_vault_path` / `omo_get_plugin_root` (no hardcoded absolute paths).
- Any new cron job must be tagged `# OMO-CRON:<name>` (so `uninstall-cron.sh` can identify it).
- Do not swallow errors silently — write to `stderr` and differentiate with exit codes.

### 4. Modify hooks

- Update `hooks/hooks.json` manifest and the hook script together.
- Hooks are **warning-only by default**. A hook that blocks user work is a design-review candidate.
- Hook failures must not be silent — log to stderr.

## Commit convention

Follow [Conventional Commits](https://www.conventionalcommits.org/) (consistent with existing history):

```
<type>: <description>

<optional body>
```

Types: `feat` · `fix` · `refactor` · `docs` · `test` · `chore` · `perf` · `ci`

Examples:

```
feat(skills): add omo-export to dump wiki as static site
fix(lint): missing-crossrefs counted only forward links
docs(readme): add team-onboarding Why OMO section
```

Keep the subject under 50 characters; use the body to explain the "why". English or Korean is fine (team convention).

**Classify by behavior impact, not file extension.** Skills live as `SKILL.md` markdown but their content *is* the runtime behavior, so:

- New skill added → `feat(skills):` (e.g. `feat(skills): add omo-project-analyze`)
- Changing a skill's procedure, decision logic, language policy, or allowed-tools → `feat(skills):` (functional change, even though the file is markdown)
- New lint check → `feat(lint):` (with the matching `scripts/lint-checks/<name>.sh`)
- New schema field or page type → `feat(schema):`
- Pure wording / typo / formatting polish with no behavior change → `docs(skills):` / `docs(readme):` / etc.

This matters operationally: `/omo-project-update` filters commits by `^(feat|fix|refactor|perf)` to generate worklog and detect decisions. Under-tagging a functional change as `docs:` makes it invisible to that skill and the work drops out of the vault's project record.

## CHANGELOG

Every contribution adds one line to the `[Unreleased]` section of `CHANGELOG.md`, under the appropriate category: `Added` / `Changed` / `Deprecated` / `Removed` / `Fixed` / `Security`.

Example:

```markdown
### Added
- `skills/omo-export/`: new skill to dump wiki as static HTML site
```

The release maintainer promotes `[Unreleased]` into a dated version heading at release time.

## Pull Request flow

1. Discuss in an issue first — especially for new skills or schema changes.
2. Work on a `feature/<slug>` or `fix/<slug>` branch.
3. PR title in Conventional Commit format.
4. PR body must include:
   - **What changed** (1–3 bullets)
   - **Why** (motivation / problem)
   - **How tested** (local verification steps)
   - Related issue numbers
5. Requires at least one reviewer approval before merge.

## Testing

There is no automated test harness yet — **manual verification is required**:

- [ ] Call each changed skill at least once after `/reload-plugins`
- [ ] Run `/omo-init` against an empty vault to validate the new-user path (when skills or install flow change)
- [ ] Run `/omo-lint` green (when the schema changes)
- [ ] Verify cron register / unregister (when cron-related code changes)
- [ ] Record the manual verification checklist results in the PR body

An automated test harness is on the v0.1 roadmap.

## Questions & issues

- Bug reports: [GitHub Issues](https://github.com/JunHyeongLee92/oh-my-obsidian/issues) with reproduction steps + `cat ~/.config/oh-my-obsidian/config.json` output + OS and Claude Code version.
- Feature proposals: include "Why this", "Proposed behavior", and "Alternatives considered".
- Design-level discussion: open an issue with the `design` label — new skills and schema changes start here.

## Code of conduct

Respectful, constructive feedback is the baseline. Hostile or discriminatory conduct is grounds for PR rejection.
