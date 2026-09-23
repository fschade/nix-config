#!/usr/bin/env bash
set -euo pipefail

flake="${MISE_PROJECT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
user="$(id -un)"
casks=0

if [ "$(uname)" = "Darwin" ]; then
  cfg="$(hostname -s)"
  known="$(nix eval --no-warn-dirty --json "${flake}#darwinConfigurations" --apply 'builtins.attrNames')"
  if ! printf '%s' "$known" | grep -qF "\"${cfg}\""; then
    echo "No darwinConfigurations entry for '${cfg}'." >&2
    echo "Known: ${known}" >&2
    exit 1
  fi
  attr="darwinConfigurations.\"${cfg}\".config.home-manager.users.\"${user}\".home.packages"
  casks=1
else
  host="$(hostname -s)"
  key="${user}@${host}"
  known="$(nix eval --no-warn-dirty --json "${flake}#homeConfigurations" --apply 'builtins.attrNames')"
  if ! printf '%s' "$known" | grep -qF "\"${key}\""; then
    echo "No homeConfigurations entry for '${key}'." >&2
    echo "Known: ${known}" >&2
    exit 1
  fi
  attr="homeConfigurations.\"${key}\".config.home.packages"
fi

echo "── nix packages (declared) ──"
nix eval --no-warn-dirty --json "${flake}#${attr}" \
  --apply 'builtins.map (p: p.pname or (p.name or "?"))' \
  | jq -r 'unique | .[]' \
  | column

if [ "$casks" = 1 ]; then
  echo
  echo "── homebrew casks (GUI apps) ──"
  if command -v brew >/dev/null 2>&1; then
    brew list --cask | column
  else
    echo "(brew not on PATH)"
  fi
fi
