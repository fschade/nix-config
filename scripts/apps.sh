#!/usr/bin/env bash
# list the apps i actually chose, not the 200+ dependency binaries on PATH too.
# two buckets:
#   - nix packages: the declared home.packages from THIS machine config
#   - GUI apps:     homebrew casks (macOS only)
# evals the config for current machine: darwin host on macOS, or matching
# homeConfigurations."<user>@<host>" on linux. each machine eval its own config.
set -euo pipefail

flake="${MISE_PROJECT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
user="$(id -un)"
casks=0

if [ "$(uname)" = "Darwin" ]; then
  # one darwin host config, take its name dynamically
  cfg="$(nix eval --no-warn-dirty --raw "${flake}#darwinConfigurations" \
    --apply 'c: builtins.head (builtins.attrNames c)')"
  attr="darwinConfigurations.\"${cfg}\".config.home-manager.users.\"${user}\".home.packages"
  casks=1
else
  host="$(hostname -s)"
  key="${user}@${host}"
  known="$(nix eval --no-warn-dirty --json "${flake}#homeConfigurations" --apply 'builtins.attrNames')"
  if ! printf '%s' "$known" | grep -q "\"${key}\""; then
    echo "No homeConfigurations entry for '${key}'." >&2
    echo "Known: ${known}" >&2
    exit 1
  fi
  attr="homeConfigurations.\"${key}\".config.home.packages"
fi

echo "── nix packages (declared) ──"
nix eval --no-warn-dirty --json "${flake}#${attr}" \
  --apply 'builtins.map (p: p.pname or (p.name or "?"))' \
  | python3 -c 'import sys,json; print("\n".join(sorted(set(json.load(sys.stdin)))))' \
  | column

if [ "$casks" = 1 ]; then
  echo
  echo "── homebrew casks (GUI apps) ──"
  brew list --cask 2>/dev/null | column || echo "(brew not on PATH)"
fi
