# .codex-plugin — Codex Plugin for oh-my-obsidian

This directory contains the Codex plugin manifest for oh-my-obsidian.

## Structure

```text
.codex-plugin/
└── plugin.json   # Codex plugin manifest
skills/           # Shared skill source used by Claude Code and Codex
schema/           # Wiki rules read by the skills and scripts
scripts/          # Vault lint, ingest, cron, digest, and sync scripts
```

## Local Development

From this repository root:

```bash
codex plugin marketplace add "$PWD"
```

The local marketplace entry points back to this repo root, so the Codex plugin
uses the same `skills/`, `schema/`, and `scripts/` files as the Claude Code
plugin.

When initializing a vault from a local clone, set the plugin root explicitly if
the agent cannot infer it:

```bash
export OMO_PLUGIN_ROOT=/Users/junhyeong/workspace/SideProject/oh-my-obsidian
```

## Codex Notes

- Codex uses `.codex-plugin/plugin.json`; Claude Code uses `.claude-plugin/plugin.json`.
- The shared skills remain the source of truth. They may mention Claude Code in
  user-facing examples because OMO started as a Claude Code plugin.
- Claude Code hooks are not registered through this Codex manifest. The
  `hooks/wiki-staleness-check.sh` script remains available for the Claude Code
  plugin surface.
- `scripts/weekly-digest.sh` supports both `claude` and `codex exec`. Set
  `OMO_DIGEST_AGENT=codex` for Codex-driven cron digests.
