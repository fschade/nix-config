#!/usr/bin/env bash
# runs after system.defaults (see modules/darwin/defaults.nix).
# runs as root in darwin-rebuild switch, act as the user in their gui session.
# args: $1 = username, $2 = mysides binary, $3 = screenshots dir
set -eu

user="$1"
mysides="$2"
screenshots="$3"

# mysides talks to the finder, so it needs the user's aqua session. plain
# `sudo -u` dont join it, this is the wrapper nix-darwin uses for the same job.
asuser() {
  launchctl asuser "$(id -u -- "$user")" sudo --user="$user" -- "$@"
}

# same path nix set for screencapture.location, handed in as $3. defaults only
# writes the location, the folder still has to exist. plain sudo, no gui session
sudo -u "$user" mkdir -p "$screenshots"

# a favorite silently missing from the sidebar is what this block exists to
# prevent, so a failed add has to be loud
add_favorite() {
  asuser "$mysides" add "$1" "$2" >/dev/null ||
    echo "defaults-postactivation: could not add finder favorite $1" >&2
}

# finder sidebar favorites via mysides. remove by name depend on the locale
# (english here), so `|| true` on the removes keeps a mismatch from failing the
# switch. nothing to report there, a name that is not in the list is the goal.
asuser "$mysides" remove "$user" >/dev/null 2>&1 || true
add_favorite "$user" "file:///Users/$user/"
asuser "$mysides" remove "Screenshots" >/dev/null 2>&1 || true
add_favorite "Screenshots" "file://$screenshots/"
asuser "$mysides" remove "Documents" >/dev/null 2>&1 || true
asuser "$mysides" remove "Recents" >/dev/null 2>&1 || true

# apply the new defaults right away, no logout needed. the symbolichotkeys write
# in modules/darwin/defaults.nix runs before this script and only lands because of
# this activateSettings call. plain sudo like the mkdir above, dont need the aqua
# session either.
#
# a private framework path, so it can move between macos versions. under set -e a
# failure here would abort the switch with the defaults already written, so warn
# instead: they are on disk and a logout applies them, no need to fail the switch.
activate=/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings
if [ -x "$activate" ]; then
  sudo -u "$user" "$activate" -u ||
    echo "postactivation: activateSettings exited nonzero, defaults need a logout to show" >&2
else
  echo "postactivation: activateSettings gone from its path, defaults need a logout to show" >&2
fi
