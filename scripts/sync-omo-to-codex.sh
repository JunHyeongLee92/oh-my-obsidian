#!/usr/bin/env bash
set -euo pipefail

# Sync oh-my-obsidian (OMO) assets into a local Codex CLI setup.
# - Backs up Codex/Agents plugin metadata before changes
# - Registers this local repo as a Codex marketplace source
# - Installs OMO skills into Codex-discovered global skill directories
# - Merges OMO into plugin marketplace metadata without removing existing plugins
# - Adds Codex global AGENTS.md guidance pointing to the OMO config SSOT
# - Generates legacy Codex prompt files for clients that still expose custom prompts

MODE="apply"
for arg in "$@"; do
  case "$arg" in
    --dry-run) MODE="dry-run" ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
AGENTS_HOME="${AGENTS_HOME:-$HOME/.agents}"

CONFIG_FILE="$CODEX_HOME/config.toml"
AGENTS_FILE="$CODEX_HOME/AGENTS.md"
SOURCE_MARKETPLACE="$REPO_ROOT/.agents/plugins/marketplace.json"
SOURCE_PLUGIN="$REPO_ROOT/.codex-plugin/plugin.json"
SOURCE_SKILLS="$REPO_ROOT/skills"
SOURCE_PLUGIN_LINK="$REPO_ROOT/.agents/plugins/oh-my-obsidian"
CODEX_MARKETPLACE="$CODEX_HOME/.agents/plugins/marketplace.json"
AGENTS_MARKETPLACE="$AGENTS_HOME/plugins/marketplace.json"
CODEX_PLUGIN_LINK="$CODEX_HOME/.agents/plugins/oh-my-obsidian"
AGENTS_PLUGIN_LINK="$AGENTS_HOME/plugins/oh-my-obsidian"
CODEX_SKILLS="$CODEX_HOME/.agents/skills"
AGENTS_SKILLS="$AGENTS_HOME/skills"
PROMPTS_DEST="$CODEX_HOME/prompts"
PROMPTS_MANIFEST="$PROMPTS_DEST/omo-prompts-manifest.txt"

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$CODEX_HOME/backups/omo-$STAMP"

log() { printf '[omo-codex-sync] %s\n' "$*"; }

run_or_echo() {
  if [[ "$MODE" == "dry-run" ]]; then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

require_path() {
  local path="$1"
  local label="$2"
  if [[ ! -e "$path" ]]; then
    log "Missing $label: $path"
    exit 1
  fi
}

require_path "$SOURCE_MARKETPLACE" "OMO marketplace manifest"
require_path "$SOURCE_PLUGIN" "OMO Codex plugin manifest"
require_path "$SOURCE_SKILLS" "OMO skills directory"

if ! command -v node >/dev/null 2>&1; then
  log "ERROR: Node.js 20+ is required"
  exit 1
fi

log "Mode: $MODE"
log "Repo root: $REPO_ROOT"
log "Codex home: $CODEX_HOME"
log "Agents home: $AGENTS_HOME"

if [[ "$MODE" == "apply" ]]; then
  mkdir -p "$BACKUP_DIR"
  [[ -f "$CONFIG_FILE" ]] && cp "$CONFIG_FILE" "$BACKUP_DIR/config.toml"
  [[ -f "$AGENTS_FILE" ]] && cp "$AGENTS_FILE" "$BACKUP_DIR/AGENTS.md"
  [[ -f "$CODEX_MARKETPLACE" ]] && cp "$CODEX_MARKETPLACE" "$BACKUP_DIR/codex-marketplace.json"
  [[ -f "$AGENTS_MARKETPLACE" ]] && cp "$AGENTS_MARKETPLACE" "$BACKUP_DIR/agents-marketplace.json"
fi

log "Ensuring Codex config exists"
run_or_echo mkdir -p "$CODEX_HOME"
if [[ "$MODE" == "apply" && ! -f "$CONFIG_FILE" ]]; then
  printf '#:schema https://developers.openai.com/codex/config-schema.json\n' > "$CONFIG_FILE"
elif [[ "$MODE" == "dry-run" && ! -f "$CONFIG_FILE" ]]; then
  printf '[dry-run] create %s\n' "$CONFIG_FILE"
fi

log "Registering local OMO marketplace in $CONFIG_FILE"
if [[ "$MODE" == "dry-run" ]]; then
  printf '[dry-run] add/update [marketplaces.oh-my-obsidian-local] source = %s\n' "$REPO_ROOT"
else
  REPO_ROOT="$REPO_ROOT" CONFIG_FILE="$CONFIG_FILE" node <<'NODE'
const fs = require('fs');

const file = process.env.CONFIG_FILE;
const repoRoot = process.env.REPO_ROOT;
let text = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
const section = 'marketplaces.oh-my-obsidian-local';
const header = `[${section}]`;
const block = `${header}
last_updated = "${new Date().toISOString().replace(/\.\d{3}Z$/, 'Z')}"
source_type = "local"
source = ${JSON.stringify(repoRoot)}
`;

const escaped = section.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const pattern = new RegExp(`\\n?\\[${escaped}\\]\\n[\\s\\S]*?(?=\\n\\[|$)`);
if (pattern.test(text)) {
  text = text.replace(pattern, `\n${block}`);
} else {
  text = `${text.replace(/\s*$/, '')}\n\n${block}`;
}
fs.writeFileSync(file, text.endsWith('\n') ? text : `${text}\n`);
NODE
fi

merge_agents_guidance() {
  local begin_marker="<!-- BEGIN OMO -->"
  local end_marker="<!-- END OMO -->"

  log "Merging OMO Codex guidance into $AGENTS_FILE"
  if [[ "$MODE" == "dry-run" ]]; then
    printf '[dry-run] add/update OMO managed block in %s\n' "$AGENTS_FILE"
    return
  fi

  mkdir -p "$(dirname "$AGENTS_FILE")"
  touch "$AGENTS_FILE"

  AGENTS_FILE="$AGENTS_FILE" \
  BEGIN_MARKER="$begin_marker" \
  END_MARKER="$end_marker" \
  node <<'NODE'
const fs = require('fs');

const file = process.env.AGENTS_FILE;
const begin = process.env.BEGIN_MARKER;
const end = process.env.END_MARKER;

let text = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
const block = `${begin}
## oh-my-obsidian

Use \`~/.config/oh-my-obsidian/config.json\` as the source of truth for oh-my-obsidian.

- Read \`vaultPath\` from that config instead of hardcoding the Obsidian vault path.
- Read \`pluginRoot\` from that config when invoking OMO scripts.
- Prefer OMO skills for vault workflows: \`omo-init\`, \`omo-ingest\`, \`omo-query\`, \`omo-project-add\`, \`omo-project-analyze\`, \`omo-project-update\`, \`omo-study\`, \`omo-lint\`, \`omo-digest\`, and \`omo-uninstall\`.
- When recording project knowledge, write to the configured vault only when the user requested it or the active OMO skill calls for it.
${end}`;

const escapedBegin = begin.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const escapedEnd = end.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const pattern = new RegExp(`${escapedBegin}[\\s\\S]*?${escapedEnd}`);

if (pattern.test(text)) {
  text = text.replace(pattern, block);
} else {
  text = `${text.replace(/\s*$/, '')}\n\n${block}`;
}

fs.writeFileSync(file, text.endsWith('\n') ? text : `${text}\n`);
NODE
}

merge_marketplace() {
  local dest="$1"
  local plugin_link="$2"
  log "Merging OMO marketplace metadata into $dest"
  if [[ "$MODE" == "dry-run" ]]; then
    printf '[dry-run] merge plugin metadata into %s\n' "$dest"
    printf '[dry-run] link %s -> %s\n' "$plugin_link" "$REPO_ROOT"
    return
  fi

  mkdir -p "$(dirname "$dest")"
  rm -rf "$plugin_link"
  ln -s "$REPO_ROOT" "$plugin_link"

  SOURCE_MARKETPLACE="$SOURCE_MARKETPLACE" DEST_MARKETPLACE="$dest" node <<'NODE'
const fs = require('fs');

const sourcePath = process.env.SOURCE_MARKETPLACE;
const destPath = process.env.DEST_MARKETPLACE;
const source = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
const current = fs.existsSync(destPath)
  ? JSON.parse(fs.readFileSync(destPath, 'utf8'))
  : { name: 'local', interface: { displayName: 'Local Plugins' }, plugins: [] };

const plugins = Array.isArray(current.plugins) ? current.plugins : [];
const incoming = Array.isArray(source.plugins) ? source.plugins : [];
const byName = new Map(plugins.map((plugin) => [plugin.name, plugin]));
for (const plugin of incoming) {
  byName.set(plugin.name, {
    ...plugin,
    source: {
      source: 'local',
      path: './oh-my-obsidian',
    },
  });
}

const next = {
  ...current,
  plugins: Array.from(byName.values()).sort((a, b) => a.name.localeCompare(b.name)),
};

fs.writeFileSync(destPath, `${JSON.stringify(next, null, 2)}\n`);
NODE
}

install_skills() {
  local dest_root="$1"
  log "Installing OMO skills into $dest_root"
  run_or_echo mkdir -p "$dest_root"

  local skill_dir skill_name dest_dir
  for skill_dir in "$SOURCE_SKILLS"/*; do
    [[ -d "$skill_dir" && -f "$skill_dir/SKILL.md" ]] || continue
    skill_name="$(basename "$skill_dir")"
    dest_dir="$dest_root/$skill_name"

    run_or_echo rm -rf "$dest_dir"
    run_or_echo mkdir -p "$dest_dir"
    run_or_echo cp -R "$skill_dir/." "$dest_dir/"

    if [[ "$MODE" == "dry-run" ]]; then
      printf '[dry-run] generate %s\n' "$dest_dir/agents/openai.yaml"
    else
      mkdir -p "$dest_dir/agents"
      SKILL_MD="$skill_dir/SKILL.md" OUT_FILE="$dest_dir/agents/openai.yaml" node <<'NODE'
const fs = require('fs');

const skillMd = process.env.SKILL_MD;
const outFile = process.env.OUT_FILE;
const text = fs.readFileSync(skillMd, 'utf8');
const frontmatter = text.match(/^---\n([\s\S]*?)\n---/);

function readField(name, fallback = '') {
  if (!frontmatter) return fallback;
  const re = new RegExp(`^${name}:\\s*(.*)$`, 'm');
  const match = frontmatter[1].match(re);
  if (!match) return fallback;
  return match[1].replace(/^["']|["']$/g, '').trim();
}

const name = readField('name', 'omo-skill');
const description = readField('description', `Use ${name}.`);
const shortDescription = description.length > 120
  ? `${description.slice(0, 117).trim()}...`
  : description;

const yaml = `interface:
  display_name: "${name.replace(/"/g, '\\"')}"
  short_description: "${shortDescription.replace(/"/g, '\\"')}"
  brand_color: "#6C5CE7"
  default_prompt: "Use $${name} for this oh-my-obsidian workflow."
policy:
  allow_implicit_invocation: true
`;

fs.writeFileSync(outFile, yaml);
NODE
    fi
  done
}

generate_prompts() {
  log "Generating OMO prompt files in $PROMPTS_DEST"
  run_or_echo mkdir -p "$PROMPTS_DEST"

  if [[ "$MODE" == "dry-run" ]]; then
    printf '[dry-run] > %s\n' "$PROMPTS_MANIFEST"
  else
    : > "$PROMPTS_MANIFEST"
  fi

  local skill_dir skill_name skill_md prompt_file
  for skill_dir in "$SOURCE_SKILLS"/omo-*; do
    [[ -d "$skill_dir" && -f "$skill_dir/SKILL.md" ]] || continue
    skill_name="$(basename "$skill_dir")"
    skill_md="$skill_dir/SKILL.md"
    prompt_file="$PROMPTS_DEST/$skill_name.md"

    if [[ "$MODE" == "dry-run" ]]; then
      printf '[dry-run] generate %s from %s\n' "$prompt_file" "$skill_md"
    else
      SKILL_NAME="$skill_name" SKILL_MD="$skill_md" PROMPT_FILE="$prompt_file" node <<'NODE'
const fs = require('fs');

const skillName = process.env.SKILL_NAME;
const skillMd = process.env.SKILL_MD;
const promptFile = process.env.PROMPT_FILE;
const source = fs.readFileSync(skillMd, 'utf8');
const body = source.replace(/^---\n[\s\S]*?\n---\n?/, '');

const descriptionMatch = source.match(/^---\n([\s\S]*?)\n---/);
let description = `Run the oh-my-obsidian ${skillName} workflow.`;
if (descriptionMatch) {
  const field = descriptionMatch[1].match(/^description:\s*(.*)$/m);
  if (field && field[1] && !field[1].startsWith('>-')) {
    description = field[1].replace(/^["']|["']$/g, '').trim();
  }
}
description = description.replace(/"/g, '\\"').slice(0, 220);

const prompt = `---
description: "${description}"
argument-hint: "[ARGS]"
---

# OMO Legacy Prompt: ${skillName}

Source: ${skillMd}

Use this prompt to run the oh-my-obsidian \`${skillName}\` workflow.

When this prompt is invoked, follow the linked skill procedure exactly. Resolve the vault and plugin paths from \`~/.config/oh-my-obsidian/config.json\` unless the skill says otherwise.

${body}`;

fs.writeFileSync(promptFile, prompt.endsWith('\n') ? prompt : `${prompt}\n`);
NODE
      printf '%s.md\n' "$skill_name" >> "$PROMPTS_MANIFEST"
    fi
  done

  if [[ "$MODE" == "apply" ]]; then
    sort -u "$PROMPTS_MANIFEST" -o "$PROMPTS_MANIFEST"
  fi
}

merge_agents_guidance
if [[ "$MODE" == "dry-run" ]]; then
  printf '[dry-run] link %s -> %s\n' "$SOURCE_PLUGIN_LINK" "$REPO_ROOT"
else
  rm -rf "$SOURCE_PLUGIN_LINK"
  ln -s ../.. "$SOURCE_PLUGIN_LINK"
fi
merge_marketplace "$CODEX_MARKETPLACE" "$CODEX_PLUGIN_LINK"
merge_marketplace "$AGENTS_MARKETPLACE" "$AGENTS_PLUGIN_LINK"
install_skills "$CODEX_SKILLS"
install_skills "$AGENTS_SKILLS"
generate_prompts

log "Sync complete"
if [[ "$MODE" == "apply" ]]; then
  log "Backup saved at: $BACKUP_DIR"
  log "Restart Codex CLI to reload OMO skills."
fi
