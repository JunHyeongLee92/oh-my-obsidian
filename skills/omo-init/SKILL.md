---
name: omo-init
description: Initialize an Obsidian vault as an oh-my-obsidian LLM wiki. Creates vault directory scaffolding from templates, writes ~/.config/oh-my-obsidian/config.json with vaultPath and pluginRoot, and registers cron jobs for lint + weekly-digest + qmd-update. Use when the user first installs oh-my-obsidian, asks to set up or bootstrap a new vault, or says things like "/omo-init <path>", "init an obsidian vault", "bootstrap the wiki", "옵시디언 볼트 초기화", "oh-my-obsidian 셋업".
origin: oh-my-obsidian
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

# omo-init — Vault Initialization

One-time setup for an Obsidian vault to be used as an LLM wiki.

## When to activate

- User invokes `/omo-init [<path>]`
- "init obsidian vault", "set up oh-my-obsidian", "bootstrap the wiki"
- "옵시디언 볼트 초기화", "oh-my-obsidian 셋업", "위키 부트스트랩"
- `~/.config/oh-my-obsidian/config.json` does not exist yet

## Interactive vs. direct mode

- **Direct mode** — when `$ARGUMENTS` has a path, proceed with that path.
- **Interactive mode** — when no path is given, **always present choices via the `AskUserQuestion` tool** (do not ask via free-text).

## Procedure

### 0. Resolve inputs (interactive if no args)

When `$ARGUMENTS` is empty, use `AskUserQuestion` to collect the path, migration decision, and cron decision.

**Question 1 — vault path**:
- header: `Vault path`
- question: "Where should the vault live?"
- multiSelect: false
- options:
  - label: `~/obsidian-vault` / description: "new vault under $HOME (recommended)"
  - label: `~/Documents/Obsidian` / description: "the traditional Obsidian Vaults location"

(The tool automatically offers "Other" → the user can type any path.)

Normalize the chosen path to an absolute path (`~` → `$HOME`). If the parent directory does not exist, you may add an extra confirmation question for `mkdir -p`.

### 1. Resolve plugin root

```bash
PLUGIN_ROOT="$HOME/.claude/plugins/marketplaces/oh-my-obsidian"
test -d "$PLUGIN_ROOT/scripts" && test -d "$PLUGIN_ROOT/templates" || {
  echo "Could not locate the plugin at: $PLUGIN_ROOT"
  exit 1
}
```

If `marketplaces` is missing, fall back to `cache/oh-my-obsidian/oh-my-obsidian/<version>/`.

### 2. Detect existing vault → ask to migrate (interactive if needed)

```bash
VAULT_PATH="<resolved>"
TODAY=$(date +%Y-%m-%d)

if [ -d "$VAULT_PATH" ] && [ -n "$(ls -A "$VAULT_PATH" 2>/dev/null)" ]; then
  EXISTING=1
else
  EXISTING=0
fi
```

If `EXISTING=1`, ask via `AskUserQuestion`:

**Question 2 — existing vault**:
- header: `Existing vault`
- question: "`$VAULT_PATH` already contains files. How should we proceed?"
- options:
  - label: `Migrate (keep files)` / description: "preserve existing files, add only the missing structure (recommended)"
  - label: `Cancel` / description: "bail out; start again with a different path"

Migrate → MODE=migrate. Cancel → exit and invite the user to re-run `/omo-init`.

### 3. Scaffold (fresh only)

Only when MODE=fresh:

```bash
mkdir -p "$VAULT_PATH"
cp -r "$PLUGIN_ROOT/templates/"* "$VAULT_PATH/"
cp -r "$PLUGIN_ROOT/templates/".[!.]* "$VAULT_PATH/" 2>/dev/null || true

# Replace the {{DATE}} token with today's date
if [[ "$OSTYPE" == "darwin"* ]]; then
  find "$VAULT_PATH" -type f -name "*.md" -exec sed -i '' "s/{{DATE}}/$TODAY/g" {} +
else
  find "$VAULT_PATH" -type f -name "*.md" -exec sed -i "s/{{DATE}}/$TODAY/g" {} +
fi
```

Common (both modes):
```bash
mkdir -p "$VAULT_PATH/_ops/lint-reports"
```

### 4. Write config.json

```bash
CONFIG_DIR="$HOME/.config/oh-my-obsidian"
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_DIR/config.json" <<JSON
{
  "vaultPath": "$VAULT_PATH",
  "pluginRoot": "$PLUGIN_ROOT",
  "syncMode": "isolated"
}
JSON
```

### 5. Cron registration (ask first)

**Question 3 — cron**:
- header: `Cron`
- question: "Register the three maintenance cron jobs (lint daily at 03:00, qmd index refresh at 03:15, weekly digest on Mondays at 03:30)? `git-sync` is not auto-registered — see README."
- options:
  - label: `Yes, register` / description: "enable automated maintenance (recommended)"
  - label: `Skip` / description: "register later, manually"

If Yes:
```bash
bash "$PLUGIN_ROOT/scripts/install-cron.sh"
```

### 6. Verify

- Print `cat "$CONFIG_DIR/config.json"`
- If cron was registered: `crontab -l | grep OMO-CRON`
- Summary of the vault directory tree: `find "$VAULT_PATH" -maxdepth 2 -type d`

### 7. Report to the user

Short report (in the user's working language):

- Vault path, MODE (fresh / migrate)
- Cron registration result (registered / skipped)
- Next steps: "Use `/omo-ingest <URL>`, `/omo-query <keyword>`, `/omo-lint`, or just ask in natural language."

## References

- Plugin files: `$PLUGIN_ROOT/scripts/install-cron.sh`, `$PLUGIN_ROOT/templates/`
- Config: `~/.config/oh-my-obsidian/config.json`

## Safety

- Never overwrite the user's existing files.
- Do not touch an existing `_sources/` or `wiki/` inside the vault.
- Cron jobs are identified by the `# OMO-CRON:<name>` tag, so other user cron entries are preserved.
- When invoked without arguments, **always use `AskUserQuestion`** to collect the input — never ask via free-text.
