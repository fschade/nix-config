#!/usr/bin/env bash

set -euo pipefail

cd "${MISE_PROJECT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

run_or_nix() {
  local cmd=$1 installable=$2
  shift 2
  if command -v "$cmd" >/dev/null 2>&1; then
    "$cmd" "$@"
  else
    nix run "$installable" -- "$@"
  fi
}

target="${usage_target:-${1:-@self}}"
if [ "$target" = "@self" ]; then
  if [ "$(uname -s)" = Darwin ]; then
    target="$(hostname -s)"
  else
    target="$(id -un)@$(hostname -s)"
  fi
fi

if [[ "$target" == *@* ]]; then
  run_or_nix home-manager home-manager/master switch -b backup --flake ".#$target"
else
  if command -v darwin-rebuild >/dev/null 2>&1; then

    sudo "$(command -v darwin-rebuild)" switch --flake ".#$target"
  else
    sudo nix run nix-darwin -- switch --flake ".#$target"
  fi

  if command -v swift >/dev/null 2>&1; then
    swift ./tools/web-app/web-app.swift build
  else
    echo "web-apps: swift not found, skipping (install Xcode command line tools)." >&2
  fi
fi
