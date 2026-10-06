#!/usr/bin/env bash
set -euo pipefail

MARKETPLACE_SOURCE="${1:-Divyansh-0909/codex-you-should-know}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 is required. $2" >&2
    exit 1
  fi
}

require_command codex "Install or update the OpenAI Codex CLI first."
require_command node "Install Node.js 18 or newer first."
require_command python3 "Python 3 is required by this installer."

node_major="$(node -p "Number(process.versions.node.split('.')[0])")"
if [ "$node_major" -lt 18 ]; then
  echo "Node.js 18+ is required. Found $(node --version)." >&2
  exit 1
fi

echo "Adding You Should Know marketplace..."
codex plugin marketplace add "$MARKETPLACE_SOURCE" --json >/dev/null

echo "Installing You Should Know..."
install_json="$(codex plugin add you-should-know@you-should-know --json)"
plugin_root="$(printf '%s' "$install_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["installedPath"])')"

if [ -z "$plugin_root" ]; then
  echo "Codex installed the plugin but did not return installedPath." >&2
  exit 1
fi

if codex features list 2>/dev/null | grep -Eq '^plugin_hooks[[:space:]]+[^[:space:]]+[[:space:]]+true[[:space:]]*$'; then
  echo "This Codex build supports plugin hooks natively; no compatibility config is needed."
else
  echo "Registering compatibility hooks for this Codex build..."
  codex_home="${CODEX_HOME:-$HOME/.codex}"
  config_path="$codex_home/config.toml"
  mkdir -p "$codex_home"
  touch "$config_path"

  YSK_CONFIG_PATH="$config_path" YSK_PLUGIN_ROOT="$plugin_root" python3 <<'PY'
import json
import os
import pathlib
import re

config_path = pathlib.Path(os.environ["YSK_CONFIG_PATH"])
root = pathlib.Path(os.environ["YSK_PLUGIN_ROOT"]).as_posix()
text = config_path.read_text(encoding="utf-8") if config_path.exists() else ""
text = re.sub(
    r"\n?# BEGIN you-should-know compatibility hooks.*?# END you-should-know compatibility hooks\n?",
    "\n",
    text,
    flags=re.S,
).rstrip()

post = f'node "{root}/hooks/post-tool-use.mjs"'
stop = f'node "{root}/hooks/stop.mjs"'
block = f'''# BEGIN you-should-know compatibility hooks
[[hooks.PostToolUse]]

[[hooks.PostToolUse.hooks]]
type = "command"
command = {json.dumps(post)}
timeout = 5

[[hooks.Stop]]

[[hooks.Stop.hooks]]
type = "command"
command = {json.dumps(stop)}
timeout = 35
statusMessage = "Checking what you should know"
# END you-should-know compatibility hooks'''

out = f"{text}\n\n{block}\n" if text else f"{block}\n"
config_path.write_text(out, encoding="utf-8")
PY
fi

echo
echo "You Should Know is installed."
echo "Restart Codex. If Codex asks to review new hooks, inspect them and choose 'Trust all and continue' to activate them."
