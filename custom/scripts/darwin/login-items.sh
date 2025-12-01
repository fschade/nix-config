#!/usr/bin/env bash
# set macOS "Open at Login" items (see modules/darwin/login-items.nix).
# runs as root in darwin-rebuild switch, act as user with sudo -u.
# clears all login items then add only the paths from args, so nix is the truth.
# || true so a denied automation prompt dont fail the switch. grant the one-time
# "control System Events" prompt so it apply.
# args: $1 = username, $2.. = app bundle paths
set -eu

user="$1"
shift

sudo -u "$user" /usr/bin/osascript \
  -e 'tell application "System Events" to delete every login item' >/dev/null || true

for path in "$@"; do
  sudo -u "$user" /usr/bin/osascript \
    -e "tell application \"System Events\" to make login item at end with properties {path:\"$path\", hidden:false}" \
    >/dev/null || true
done
