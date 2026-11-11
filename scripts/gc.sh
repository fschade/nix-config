#!/usr/bin/env bash

set -euo pipefail

retention="${usage_retention:-${1:-30d}}"

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

layouts="${XDG_STATE_HOME:-$HOME/.local/state}/direnv/layouts"
if [ -d "$layouts" ]; then
  stale=0
  # NUL-separated: a newline in a project path would otherwise split into a relative path for rm
  while IFS= read -r -d '' profile; do
    dir=${profile%/*}
    project="/${dir#"$layouts"/}"
    if [ ! -d "$project" ]; then
      rm -rf -- "$dir"
      stale=$((stale + 1))
    fi
  done < <(find "$layouts" -name 'flake-profile-*' ! -name '*.rc' -print0)
  [ "$stale" -gt 0 ] && printf 'dropped %s direnv layout(s) whose project is gone\n\n' "$stale"
fi

state before
printf 'deleting generations older than %s, then collecting\n\n' "$retention"
sudo "$collector" --delete-older-than "$retention"
printf '\n'
state after
