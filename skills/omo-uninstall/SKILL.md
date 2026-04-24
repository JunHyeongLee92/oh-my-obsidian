---
name: omo-uninstall
description: Remove oh-my-obsidian cron jobs and optionally delete the config file. Never touches the user's vault data (wiki/, projects/, _sources/). Use when the user says "/omo-uninstall", "uninstall oh-my-obsidian", "remove omo cron", "oh-my-obsidian 제거", "omo 언인스톨", or when migrating to a different machine / plugin location.
origin: oh-my-obsidian
allowed-tools: Bash, Read, AskUserQuestion
---

# omo-uninstall — Safe Cleanup

Removes OMO's infrastructure (cron + optional config) while preserving the user's vault data intact.

## When to activate

- `/omo-uninstall`
- "remove oh-my-obsidian", "uninstall omo", "clear the cron"
- "oh-my-obsidian 제거", "omo 삭제", "크론 지워"
- Right before removing the plugin itself via `/plugin uninstall`

## Procedure

### 1. Confirm intent + config decision (interactive)

**Always use the `AskUserQuestion` tool to present the choices — never rely on free-text confirmation.**

Bundle both questions into a single call:

**Question 1 — proceed**:
- header: `Uninstall`
- question: "Remove oh-my-obsidian cron entries and config. Proceed? (Vault data will not be touched.)"
- options:
  - label: `Yes, proceed` / description: "Remove cron + apply the selected config action"
  - label: `Cancel` / description: "Exit without changing anything"

**Question 2 — config**:
- header: `Config`
- question: "Also delete `~/.config/oh-my-obsidian/config.json`?"
- options:
  - label: `Keep config` / description: "Reinstalling later picks up the same config (recommended)"
  - label: `Delete config` / description: "Complete wipe; reinstall will require `/omo-init` again"

If Q1 is `Cancel`, exit and tell the user "Nothing was changed."

### 2. Remove cron

```bash
CONFIG=~/.config/oh-my-obsidian/config.json
PLUGIN=$(node -e "process.stdout.write(require('$CONFIG').pluginRoot || process.env.HOME+'/.claude/plugins/marketplaces/oh-my-obsidian')" 2>/dev/null || echo "$HOME/.claude/plugins/marketplaces/oh-my-obsidian")
bash "$PLUGIN/scripts/uninstall-cron.sh"
```

`uninstall-cron.sh` only strips lines tagged `# OMO-CRON:` — any other crontab entry is left alone.

### 3. Apply the config decision

Based on the Q2 selection:

```bash
# Delete config
rm ~/.config/oh-my-obsidian/config.json
rmdir ~/.config/oh-my-obsidian 2>/dev/null || true

# Keep config
# (do nothing)
```

### 4. Verify

```bash
crontab -l | grep OMO-CRON || echo "No OMO cron entries (OK)"
```

### 5. Report

Short report (in the user's working language):

- number of cron entries removed
- whether the config was kept or deleted
- explicit note that vault data is untouched
- point out that the plugin files themselves can be removed via `/plugin uninstall oh-my-obsidian`

## Safety

- **Never touch vault data.** Do not delete anything under `wiki/`, `projects/`, `_sources/`, or `_ops/lint-reports/`.
- Cron removal is tag-based, so it does not affect any other user cron entry.
- Always confirm via `AskUserQuestion` before running any of the destructive steps. Never prompt via free-text.
