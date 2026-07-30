#!/usr/bin/env bash

set -euo pipefail

# nix-darwins nix.gc options do nothing here: determinate brings its own daemon
# and modules/darwin/nix.nix sets nix.enable = false. so collecting is a task
# you call. old generations are what `mise run rollback` needs, which is why
# nothing throws them away on a timer.

# mise fills usage_retention from its arg spec, $1 is for a direct ./scripts/gc.sh
retention="${usage_retention:-${1:-30d}}"

# nix-collect-garbage sits in /nix/var/nix/profiles/default/bin, not on sudo's
# secure_path
if ! collector="$(command -v nix-collect-garbage)"; then
  echo "nix-collect-garbage not on PATH, nothing to collect with." >&2
  exit 1
fi

state() {
  local generations free
  generations=$(find /nix/var/nix/profiles -maxdepth 3 -name '*-link' | wc -l | tr -d ' ')
  free=$(df -h /nix | awk 'NR == 2 {print $4}')
  printf '%-6s %s profile generations, %s free\n' "$1" "$generations" "$free"
}

# nix-direnv keeps its layout, and one gc root per flake input, under the cache
# (see custom/scripts/common/direnv-layout-dir.sh). the layout path mirrors the
# project path, so a deleted checkout leaves a layout that still pins its inputs.
# drop the layouts whose project is gone, before collecting, so their store paths
# come free in this same run.
layouts="${XDG_CACHE_HOME:-$HOME/.cache}/direnv/layouts"
if [ -d "$layouts" ]; then
  stale=0
  # a leaf layout holds a flake-profile; its dir maps back to /<path-below-layouts>
  while IFS= read -r profile; do
    dir=$(dirname "$profile")
    project="/${dir#"$layouts"/}"
    if [ ! -d "$project" ]; then
      rm -rf "$dir"
      stale=$((stale + 1))
    fi
  done < <(find "$layouts" -name 'flake-profile-*' ! -name '*.rc' 2>/dev/null)
  [ "$stale" -gt 0 ] && printf 'dropped %s direnv layout(s) whose project is gone\n\n' "$stale"
fi

state before
printf 'deleting generations older than %s, then collecting\n\n' "$retention"
sudo "$collector" --delete-older-than "$retention"
printf '\n'
state after
