#!/usr/bin/env bash
# List the apps you actually *chose* — not the 200+ transitive dependency
# binaries that also land on PATH. Two buckets:
#   - nix packages: the declared `home.packages` from THIS machine's config
#   - GUI apps:      homebrew casks (macOS only)
# Evaluates the config for the current machine: the darwin host on macOS, or the
# matching homeConfigurations."<user>@<host>" on Linux. Each machine evaluates
# its own (native) config.
set -euo pipefail

flake="${MISE_PROJECT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
user="$(id -un)"
casks=0

if [ "$(uname)" = "Darwin" ]; then
  # one darwin host config — take its name dynamically
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
