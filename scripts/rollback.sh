#!/usr/bin/env bash

set -euo pipefail

if [ "$(uname -s)" = Darwin ]; then
  if ! rebuild="$(command -v darwin-rebuild)"; then
    echo "darwin-rebuild not on PATH, nothing to roll back with." >&2
    exit 1
  fi
  sudo "$rebuild" --rollback
else
  home-manager generations
  echo "Run the chosen generation's activate script to roll back."
fi
