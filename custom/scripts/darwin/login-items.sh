#!/usr/bin/env bash
# set macOS "Open at Login" items (see modules/darwin/login-items.nix).
# runs as root in darwin-rebuild switch, act as the user in their gui session.
# clears all login items then add only the paths from args, so nix is the truth.
# a step can fail without a config bug behind it: denied automation prompt, or an
# app that is not built on this host yet. a failed add warns and the run goes on,
# a failed delete stops here, adding on top of an uncleared list would double
# every item. either way exit 0: this runs before /run/current-system is swung, a
# hard exit would leave the switch half done. grant the one-time "control System
# Events" prompt so it apply, see MANUAL.md
# args: $1 = username, $2.. = app bundle paths
set -eu

user="$1"
shift

# System Events lives in the user's aqua session, plain `sudo -u` dont join it.
# same wrapper nix-darwin uses for its own user-level steps.
osa() {
  launchctl asuser "$(id -u -- "$user")" sudo --user="$user" -- \
    /usr/bin/osascript -e "$1" >/dev/null
}

if ! osa 'tell application "System Events" to delete every login item'; then
  echo "login-items: cannot reach System Events, login items left untouched" >&2
  exit 0
fi

failed=0
for path in "$@"; do
  # the path goes into an applescript string literal, so a `"` or `\` in a
  # bundle name would end the literal and break the whole line
  escaped=${path//\\/\\\\}
  escaped=${escaped//\"/\\\"}
  if ! osa "tell application \"System Events\" to make login item at end with properties {path:\"$escaped\", hidden:false}"; then
    echo "login-items: could not add $path" >&2
    failed=$((failed + 1))
  fi
done

if [ "$failed" -gt 0 ]; then
  echo "login-items: $failed of $# items are missing, see above" >&2
fi
