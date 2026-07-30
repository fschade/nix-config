#!/usr/bin/env bash

set -euo pipefail

if [ "$(uname -s)" = Darwin ]; then
  # darwin-rebuild sits in /run/current-system/sw/bin, sudo's secure_path does
  # not have it. resolve before, not after
  if ! rebuild="$(command -v darwin-rebuild)"; then
    echo "darwin-rebuild not on PATH, nothing to roll back with." >&2
    exit 1
  fi
  sudo "$rebuild" --rollback
else
  # home-manager has no one-shot rollback, pick a previous generation:
  home-manager generations
  echo "Run the chosen generation's activate script to roll back."
fi
