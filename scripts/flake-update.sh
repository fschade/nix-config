#!/usr/bin/env bash

set -euo pipefail

cd "${MISE_PROJECT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# update every top-level flake input except the pinned homebrew taps. those churn
# many times an hour, bumping them here moves flake.lock on every run. refresh on
# purpose with `mise run brew-update`. brew-src stays in, its a version tag so it
# cant drift
names="$(
  nix flake metadata --json |
    jq -r '.locks.nodes.root.inputs | keys[]'
)"
# grep exits 1 when everything got filtered out, the guard below wants to report
# that itself
list="$(printf '%s\n' "$names" | grep -v '^homebrew-' || true)"

# an empty array turns the line below into a bare `nix flake update`, which
# recreates the lock and bumps the very taps this filter excludes
IFS=$'\n' read -r -d '' -a inputs <<<"$list" || true
if [ "${#inputs[@]}" -eq 0 ]; then
  echo "no flake inputs to update, refusing to fall back to updating all of them." >&2
  exit 1
fi

nix flake update "${inputs[@]}"
