#!/usr/bin/env bash
set -eu

user="$1"
shift

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
