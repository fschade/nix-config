#!/usr/bin/env bash

set -euo pipefail

# flake refs below are relative, so run from the repo root even when invoked
# directly (mise sets the cwd, a plain ./scripts/deploy.sh doesn't)
cd "${MISE_PROJECT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

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

# resolve "@self" to this machine: a bare hostname is the nix-darwin system,
# "<user>@<hostname>" is home-manager. hostname -s because the flake keys are
# short and uname -n may carry the FQDN.

# mise fills usage_target from its arg spec, $1 is for a direct ./scripts/deploy.sh
target="${usage_target:-${1:-@self}}"
if [ "$target" = "@self" ]; then
  if [ "$(uname -s)" = Darwin ]; then
    target="$(hostname -s)"
  else
    # id -un, not $USER: set -u kills us wherever the login shell didnt export it
    target="$(id -un)@$(hostname -s)"
  fi
fi

if [[ "$target" == *@* ]]; then
  run_or_nix home-manager home-manager/master switch -b backup --flake ".#$target"
else
  # fresh machine: no darwin-rebuild yet, bootstrap the same way the README does
  if command -v darwin-rebuild >/dev/null 2>&1; then
    # a switch never touches the lock, so brew stays at whatever the pinned taps
    # hold. bump with `mise run brew-update`

    # resolve before sudo, /run/current-system/sw/bin is not on secure_path
    sudo "$(command -v darwin-rebuild)" switch --flake ".#$target"
  else
    sudo nix run nix-darwin -- switch --flake ".#$target"
  fi

  # native web-app wrappers nix cant build (needs swiftc). runs as the user, not
  # root, since it writes to /Applications and codesigns. see custom/web-apps/.
  if command -v swift >/dev/null 2>&1; then
    swift ./tools/web-app/web-app.swift build

    # a web-app that is also a login item only exists now, after the build. the
    # switch reconciled login items before it, so it warned that one missing.
    # reconcile once more, it is idempotent and now the app is there.
    if [ -f /etc/login-items ]; then
      # read loop, not mapfile: a fresh machine runs this under /bin/bash 3.2.
      # the `|| [ -n ]` keeps a last line without trailing newline
      items=()
      while IFS= read -r line || [ -n "$line" ]; do
        items+=("$line")
      done </etc/login-items
      sudo bash ./custom/scripts/darwin/login-items.sh "$(id -un)" "${items[@]}"
    fi
  else
    echo "web-apps: swift not found, skipping (install Xcode command line tools)." >&2
  fi
fi
