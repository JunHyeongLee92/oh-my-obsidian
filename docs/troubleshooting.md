# Troubleshooting

**English** · [한국어](troubleshooting.ko.md)

Common install and runtime issues, organized as **symptom / cause / fix**. For anything not listed here, open a [GitHub Issue](https://github.com/JunHyeongLee92/oh-my-obsidian/issues).

## Install

### `omo_require_node` or "Node.js 20+ is required" error

**Symptom**: Any skill invocation prints `ERROR: Node.js 20+ is required.`.

**Cause**: `scripts/lib/config.sh` uses Node.js for JSON parsing; the system `node` binary is missing or too old.

**Fix**:

```bash
node --version   # verify v20+
# install via nvm / mise / homebrew / apt if missing
nvm install 20 && nvm use 20
# or
brew install node
```

After install, make sure cron sees the same PATH — consider adding a `PATH=` line at the top of `crontab -e` (especially with nvm).

### Config file missing after `/omo-init`

**Symptom**: `cat ~/.config/oh-my-obsidian/config.json` → `No such file or directory`.

**Cause**: `/omo-init` exited early with an error, or `$XDG_CONFIG_HOME` is set to a non-default path.

**Fix**:

```bash
# Check any XDG override
echo ${XDG_CONFIG_HOME:-$HOME/.config}

# Re-run if missing
/omo-init <vault-path>
```

If it still doesn't get created, inspect the vault-path permissions (`ls -ld <vault-path>`).

### `/plugin install` reports "already installed" but content is outdated

**Symptom**: `/plugin install oh-my-obsidian` prints "already installed" yet the cached skills / hook / scripts still behave like the previous release.

**Cause**: Claude Code caches plugins by version tag under `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`. When a release ships without bumping the version (or during local iteration on the same version), the cache never refreshes.

**Fix**: delete the stale cache directory and reinstall.

```bash
rm -rf ~/.claude/plugins/cache/oh-my-obsidian/oh-my-obsidian/<version>
/plugin install oh-my-obsidian
/reload-plugins
```

For normal releases, bump `.claude-plugin/plugin.json:version` + `.claude-plugin/marketplace.json:version` to a new SemVer — Claude Code auto-refreshes the cache on `/plugin install` when the version differs.

### Plugin installed but skills don't match natural language

**Symptom**: Slash commands like `/omo-ingest` work, but "add this URL to the wiki" isn't matched.

**Cause**: `/reload-plugins` was skipped, or the skill's `description` field has no natural-language trigger examples.

**Fix**:

```
/reload-plugins
```

If you edited a skill locally, include natural-language trigger examples in `description` so intent matching fires. See `CONTRIBUTING.md`.

## Cron

### Cron not registered / `crontab: command not found`

**Symptom**: `/omo-init` output shows cron registration failed.

**Cause**:
- macOS: recent versions disable `cron` by default; you need `launchd`.
- WSL: the `cron` service is not started by default.

**Fix**:

```bash
# WSL
sudo service cron start
# To auto-start on boot, add to /etc/wsl.conf: [boot] command = service cron start

# macOS (alternative: hand-crafted launchd plist, or re-enable cron)
sudo launchctl load -F /System/Library/LaunchDaemons/com.vix.cron.plist
```

### Cron registered but lint / digest never run

**Symptom**: `crontab -l | grep OMO-CRON` shows entries, but `_ops/lint-reports/` receives no reports.

**Cause**: cron's `PATH` does not include `node` or `claude` (user shell PATH differs from cron PATH).

**Fix**: check the logs first.

```bash
tail -50 <vault>/_ops/lint-reports/cron.log
tail -50 ~/.local/state/oh-my-obsidian/qmd-update.log
tail -50 ~/.local/state/oh-my-obsidian/weekly-digest.log
```

If you see `command not found: node` / `claude`, pin PATH at the top of crontab:

```
PATH=/home/<user>/.nvm/versions/node/v20.11.0/bin:/usr/local/bin:/usr/bin:/bin
```

### Cron remains after `omo-uninstall`

**Symptom**: Uninstall ran, but `crontab -l` still shows OMO lines.

**Cause**: The lingering lines lack the `# OMO-CRON:<name>` tag (usually from manual additions).

**Fix**: Remove the lines manually via `crontab -e`, or re-tag them and re-run `uninstall-cron.sh`.

## Lint

### `/omo-lint` reports CRITICAL but never prompts for auto-fix

**Symptom**: The lint report contains CRITICAL items, yet Claude exits without offering a fix.

**Cause**: The skill's AskUserQuestion guard fires only when CRITICAL is present. The report format may be malformed, so parsing failed.

**Fix**: Inspect the report directly.

```bash
cat <vault>/_ops/lint-reports/latest-$(hostname).md
```

If empty or malformed, run `bash scripts/lint.sh` manually and check stderr.

### Lint flags a freshly created page

**Symptom**: A freshly created page is flagged by `missing-crossrefs` (INFO) or `orphan-pages` (WARN).

**Cause**: Those checks rely on **reverse references from other pages** and **being listed in `index.md`**. A brand-new page isn't indexed yet. Neither check fires as CRITICAL — both are advisory by design.

**Fix**: Using the auto-promotion path via `/omo-ingest` or `/omo-query` handles index registration for you. If you created the page manually, add a line to `wiki/index.md`. See `schema/lint-rules.md` for the full severity table (CRITICAL / WARN / INFO).

## Ingest / Clip

### `/omo-ingest` produces an empty body

**Symptom**: `_sources/articles/<name>.md` was created but the body is nearly empty.

**Cause**:
- The target site is JavaScript-rendered (the static HTML parser can't reach the content).
- Paywall or bot block.
- The URL is a redirect loop.

**Fix**:
- Open the site in a browser's Reading Mode, then paste content into a manual page (`_ops/templates/source-ingest.md`).
- Or use `/omo-study <URL>` instead — it fetches and interprets context with the agent.

### `/omo-ingest` misclassifies the category

**Symptom**: A paper URL ends up under `_sources/articles/`.

**Cause**: The LLM infers category from title and body only; when ambiguous, the fallback is `articles`.

**Fix**: Specify the category on re-run.

```
/omo-ingest https://arxiv.org/abs/... category=papers
```

Or use natural language: "put this paper into _sources/papers".

## Weekly digest

### `weekly-digest.sh: claude not found in PATH`

**Symptom**: Cron log shows `ERROR: claude not found in PATH` and exit 127.

**Cause**: Cron cannot find the Claude CLI.

**Fix**: Add the Claude CLI path to the crontab PATH line, or set `CLAUDE_BIN`.

```bash
# At the top of crontab -e
CLAUDE_BIN=/home/<user>/.local/bin/claude
```

### Running `omo-digest` says "this week's digest already exists"

**Symptom**: Manual invocation of `omo-digest` exits with "this week's digest already exists".

**Cause**: By design, the digest is generated only once per week (duplicate prevention).

**Fix**: To force regeneration, remove the existing file and re-run.

```bash
rm <vault>/wiki/digests/$(date +%Y-W%V).md
/omo-digest
```

## Obsidian integration

### Templater templates don't appear inside Obsidian

**Symptom**: `Ctrl/Cmd+P` → "Insert template" does not list `wiki-entity` and friends.

**Cause**: `.obsidian/templates.json` might not point at `_ops/templates/` any more (Obsidian may have overwritten it with defaults when first opening the vault).

**Fix**:

```bash
cat <vault>/.obsidian/templates.json
# verify "folder": "_ops/templates"
```

If it's wrong: Obsidian Settings → Templates → Template folder location → set to `_ops/templates`.

### Built-in Templates conflict with Templater plugin

**Symptom**: Templater syntax like `<% tp.date.now() %>` is inserted as a literal string.

**Cause**: The core Templates plugin is enabled (it doesn't understand Templater variables).

**Fix**: Obsidian Settings → Core plugins → Templates **OFF**; Community plugins → Templater **ON**.

## Multi-machine

### `/omo-lint` reports get overwritten across machines

**Symptom**: Machine A's lint report is overwritten by Machine B.

**Cause**: **By design this should not happen** — lint reports are stored as `latest-<hostname>.md`, per-host. If overwriting actually occurs, both machines share the same `hostname`.

**Fix**:

```bash
hostname
# Confirm each machine has a distinct value; change /etc/hostname if needed.
```

### git-sync conflicts

**Symptom**: After editing on multiple machines, the next sync raises a git merge conflict.

**Cause**: OMO has no automatic conflict-resolution strategy yet (by design, the user resolves manually).

**Fix**:

```bash
cd <vault>
git status
# Resolve conflicts manually
git add -A && git commit -m "resolve: merge conflicts from multi-machine sync"
git push
```

Long-term, it's more reliable to nominate a single "editor" machine and stagger sync timing.

## Plugin hooks

### No staleness warning on commit

**Symptom**: Editing and committing project code produces no warning about stale wiki pages.

**Cause**:
- `hooks/hooks.json` isn't registered with Claude Code (`/reload-plugins` is needed).
- Hook script lacks execute permission (`chmod +x hooks/wiki-staleness-check.sh`).
- The project hasn't been linked to the vault via `/omo-project-add` (no `projects/<name>/`).
- `jq` is not installed on the system. The hook parses the Claude Code tool-call JSON with `jq`; if `jq` is missing the script silently exits 0 (no warning).

**Fix**:

```bash
ls -l hooks/wiki-staleness-check.sh  # verify executable bit
command -v jq >/dev/null || { brew install jq; }   # or: apt-get install jq
/reload-plugins
# From the project root
/omo-project-add
```

### Hook no longer fires after upgrading to v0.0.3+

**Symptom**: After the plugin update, the staleness warning stops appearing on commit in projects that used to warn correctly.

**Cause**: v0.0.3 renamed the project-contract key in `CLAUDE.md` from `프로젝트명:` (Korean) to `project-name:` (English). Projects linked with an older version still carry the Korean key, which the new hook no longer matches.

**Fix**: per linked project root:

```bash
sed -i 's/- 프로젝트명: /- project-name: /' CLAUDE.md
```

Or re-run `/omo-project-add` — it overwrites the legacy line with the new key via an AskUserQuestion confirmation.

## Project skills

### `/omo-project-update` reports "0 commits"

**Symptom**: Invoking `/omo-project-update <name>` on a project that clearly has recent work returns "No meaningful commits since $UPDATED".

**Cause**:
- The skill filters commit messages by `^(feat|fix|refactor|perf)` — `chore` / `docs` / `test` commits are excluded by design. Under-tagging a functional change as `docs:` makes it invisible.
- After a clean-slate release (orphan commit + force-push), pre-wipe `feat`/`fix` commits become unreachable from `main`.

**Fix**:

1. Check the commit prefix convention — see [CONTRIBUTING.md § Commit convention](../CONTRIBUTING.md#commit-convention). New skills and functional skill edits must use `feat(skills):`, not `docs(skills):`.
2. Since v0.0.3 the skill includes a **reflog fallback** (Tier 2): when `main` returns 0 matches, it retries `git log -g --since=$UPDATED` over the HEAD reflog (default 90-day retention). The Step 7 report cites `COMMIT_SOURCE=reflog` when this path fires.
3. If the reflog has rolled off (> 90 days or a fresh clone on another machine), either run the skill with an explicit hint ("update based on these commits: `<sha1>`, `<sha2>`"), or hand-edit `projects/<name>/worklog/<today>.md`.

## Diagnostic commands

When the problem is fuzzy, **take a snapshot of the state**:

```bash
# 1. Config SSOT
cat ~/.config/oh-my-obsidian/config.json

# 2. Registered cron jobs
crontab -l | grep OMO-CRON

# 3. Recent cron logs
tail -20 ~/.local/state/oh-my-obsidian/*.log

# 4. Lint reports
ls -lt <vault>/_ops/lint-reports/

# 5. Node / Claude CLI / jq presence
node --version
command -v claude
command -v jq

# 6. Plugin path — resolved + on-disk
echo "$CLAUDE_PLUGIN_ROOT"
jq -r .pluginRoot ~/.config/oh-my-obsidian/config.json 2>/dev/null
ls -la ~/.claude/plugins/cache/oh-my-obsidian/oh-my-obsidian/ 2>/dev/null
ls -la ~/.claude/plugins/marketplaces/oh-my-obsidian/ 2>/dev/null
```

Pasting the output of these six blocks into an issue drastically shortens reproduction time.
