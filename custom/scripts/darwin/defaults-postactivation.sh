#!/usr/bin/env bash
set -eu

user="$1"
mysides="$2"
screenshots="$3"

asuser() {
  launchctl asuser "$(id -u -- "$user")" sudo --user="$user" -- "$@"
}

sudo -u "$user" mkdir -p "$screenshots"

add_favorite() {
  asuser "$mysides" add "$1" "$2" >/dev/null ||
    echo "defaults-postactivation: could not add finder favorite $1" >&2
}

asuser "$mysides" remove "$user" >/dev/null 2>&1 || true
add_favorite "$user" "file:///Users/$user/"
asuser "$mysides" remove "Screenshots" >/dev/null 2>&1 || true
add_favorite "Screenshots" "file://$screenshots/"
asuser "$mysides" remove "Documents" >/dev/null 2>&1 || true
asuser "$mysides" remove "Recents" >/dev/null 2>&1 || true

activate=/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings
if [ -x "$activate" ]; then
  sudo -u "$user" "$activate" -u ||
    echo "postactivation: activateSettings exited nonzero, defaults need a logout to show" >&2
else
  echo "postactivation: activateSettings gone from its path, defaults need a logout to show" >&2
fi
