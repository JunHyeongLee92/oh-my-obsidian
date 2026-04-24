#!/usr/bin/env bash
# config.sh — shared helpers for reading oh-my-obsidian config
#
# Config file: ~/.config/oh-my-obsidian/config.json
# Shape:
#   {
#     "vaultPath": "/abs/path/to/vault",
#     "syncMode": "isolated" | "git-central"
#   }
#
# Source this file from any script that needs the vault path:
#   source "$(dirname "$0")/lib/config.sh"
#   VAULT_ROOT=$(omo_get_vault_path)

OMO_CONFIG_PATH="${OMO_CONFIG_PATH:-$HOME/.config/oh-my-obsidian/config.json}"

omo_require_node() {
  if ! command -v node >/dev/null 2>&1; then
    echo "ERROR: Node.js 20+ is required. Install it and retry." >&2
    return 1
  fi
}

omo_get_vault_path() {
  omo_require_node || return 1
  if [ ! -f "$OMO_CONFIG_PATH" ]; then
    echo "ERROR: config file not found: $OMO_CONFIG_PATH" >&2
    echo "Run /omo-init <path> first to initialize the vault." >&2
    return 1
  fi
  node -e "
    const fs = require('fs');
    const cfg = JSON.parse(fs.readFileSync('$OMO_CONFIG_PATH', 'utf8'));
    if (!cfg.vaultPath) {
      console.error('ERROR: config is missing vaultPath.');
      process.exit(1);
    }
    process.stdout.write(cfg.vaultPath);
  "
}

omo_get_plugin_root() {
  omo_require_node || return 1
  if [ ! -f "$OMO_CONFIG_PATH" ]; then
    return 1
  fi
  node -e "
    const fs = require('fs');
    const path = require('path');
    const cfg = JSON.parse(fs.readFileSync('$OMO_CONFIG_PATH', 'utf8'));
    const fallback = path.join(process.env.HOME, '.claude/plugins/marketplaces/oh-my-obsidian');
    process.stdout.write(cfg.pluginRoot || fallback);
  "
}

omo_get_config_value() {
  local key="$1"
  omo_require_node || return 1
  if [ ! -f "$OMO_CONFIG_PATH" ]; then
    return 1
  fi
  node -e "
    const fs = require('fs');
    const cfg = JSON.parse(fs.readFileSync('$OMO_CONFIG_PATH', 'utf8'));
    process.stdout.write(String(cfg['$key'] ?? ''));
  "
}
