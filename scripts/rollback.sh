#!/usr/bin/env bash

set -euo pipefail

if [ "$(uname -s)" = Darwin ]; then
  sudo darwin-rebuild --rollback
else
  # home-manager has no one-shot rollback, pick a previous generation:
  home-manager generations
  echo "Run the chosen generation's activate script to roll back."
fi
