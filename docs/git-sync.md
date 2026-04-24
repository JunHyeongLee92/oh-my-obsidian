# Git auto-backup (optional)

**English** · [한국어](git-sync.ko.md)

OMO ships `git-sync.sh`, which pushes and pulls the vault against a git remote on a schedule. `/omo-init` **does not** register this automatically — a fresh vault typically has no remote or SSH auth set up, so sync would only keep failing. Attach a remote first, then add the cron entry manually.

## Prerequisites

- `jq` installed (the cron snippet below resolves the plugin path from `~/.config/oh-my-obsidian/config.json` via `jq`).
- A git remote you can push to (any standard host — GitHub, GitLab, self-hosted).
- An SSH key registered with that remote host.

## 1. Attach a remote to the vault (one-time)

```bash
cd ~/my-vault
git init
git remote add origin git@github.com:<user>/<vault-repo>.git
git add -A && git commit -m "initial vault"
git push -u origin main
```

## 2. Prepare an SSH key

`git-sync.sh` searches in this order and uses the first key it finds:

1. `$GIT_SYNC_SSH_KEY` (explicit path via env var)
2. `~/.ssh/id_ed25519`
3. `~/.ssh/id_rsa`

As long as one of these is registered with the remote host, sync works. If none is found, the script falls back to your default git/ssh configuration (only a warning is logged).

## 3. Register in crontab

Tag the cron line with `# OMO-CRON:sync` so `uninstall-cron.sh` / `omo-uninstall` pick it up for cleanup.

```bash
# Resolve the plugin path from config — works across Claude Code install layouts
# (marketplace clone vs cache vs CLAUDE_PLUGIN_ROOT symlink)
PLUGIN_ROOT=$(jq -r .pluginRoot ~/.config/oh-my-obsidian/config.json)
(crontab -l 2>/dev/null; echo "0 */4 * * * bash $PLUGIN_ROOT/scripts/git-sync.sh >> $HOME/.local/state/oh-my-obsidian/git-sync.log 2>&1 # OMO-CRON:sync") | crontab -
```

To change the schedule, edit only the leading `0 */4 * * *` (every 4 hours):

- `*/30 * * * *` — every 30 minutes
- `0 * * * *` — every hour on the hour
- `0 9,21 * * *` — 09:00 and 21:00

## How it works

Each invocation of `git-sync.sh` runs:

1. Acquires a lock directory `/tmp/oh-my-obsidian-git-sync.lock` to prevent overlapping runs.
2. Locates an SSH key and sets `GIT_SSH_COMMAND`.
3. `git fetch --prune origin`
4. `git pull --rebase --autostash origin main` — local uncommitted changes are auto-stashed before rebase and restored after.
5. `git add -A && git commit -m "chore: vault backup YYYY-MM-DD HH:MM"`
6. If there are no changes, skip; otherwise `git push origin main`.
7. If the `qmd` CLI is installed, refresh the index (optional).

Every step is timestamped into `~/.local/state/oh-my-obsidian/git-sync.log`.

## Troubleshooting

### Check the log

```bash
tail -50 ~/.local/state/oh-my-obsidian/git-sync.log
```

### Common issues

- **`No readable SSH key found`** — none of the keys in step 2 exists, or permissions are not `600` (`chmod 600 ~/.ssh/id_ed25519`).
- **`Another git-sync process is already running`** — a previous run died and left the lock. `rm -rf /tmp/oh-my-obsidian-git-sync.lock`.
- **Rebase conflicts** — autostash cannot resolve every conflict; manual intervention may be needed. See [troubleshooting.md](troubleshooting.md#git-sync-conflicts) for the full recipe.
- **Cron runs but nothing is pushed** — cron's `PATH` may not include `git`. Add `PATH=/usr/local/bin:/usr/bin:/bin` at the top of your crontab.

### Removal

```bash
/omo-uninstall          # or
bash scripts/uninstall-cron.sh
```

Any entry tagged `# OMO-CRON:sync` is removed alongside the other OMO cron jobs.

## Multi-machine notes

When two machines edit the same vault concurrently, rebase conflicts can occur. By design:

- `git pull --rebase --autostash` absorbs most lightweight concurrent edits.
- If both machines edit the same line in the same file, manual resolution is required.
- Nominating one machine as the "primary editor" and keeping others read-only is the safer operating model.

Detailed conflict resolution lives in [troubleshooting.md](troubleshooting.md#git-sync-conflicts).
