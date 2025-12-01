#!/usr/bin/env bash

set -euo pipefail

# run a CLI if installed, else fall back to nix run so a fresh machine can
# bootstrap without it. usage: run_or_nix <cmd> <installable> args...
run_or_nix() {
  local cmd=$1 installable=$2
  shift 2
  if command -v "$cmd" >/dev/null 2>&1; then
    "$cmd" "$@"
  else
    nix run "$installable" -- "$@"
  fi
}

# resolve "@self" to this machine flake target:
#   macOS host      nix-darwin system, keyed by hostname (e.g. mac-studio)
#   everything else home-manager, keyed "<user>@<hostname>"
target="$usage_target"
if [ "$target" = "@self" ]; then
  if [ "$(uname -s)" = Darwin ]; then
    target="$(uname -n)"
  else
    target="$USER@$(uname -n)"
  fi
fi

# "<user>@<host>" target is home-manager, a bare hostname is a darwin system
if [[ "$target" == *@* ]]; then
  run_or_nix home-manager home-manager/master switch -b backup --flake ".#$target"
else
  # using plain nix-darwin:
  sudo "$(command -v darwin-rebuild)" switch --flake ".#$target"
  # using nh, --show-activation-logs stream the output like cask/mas upgrades:
  # run_or_nix nh nixpkgs#nh darwin switch --show-activation-logs ".#$target"
fi
