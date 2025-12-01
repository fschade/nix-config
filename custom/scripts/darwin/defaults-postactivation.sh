#!/usr/bin/env bash
# runs after system.defaults (see modules/darwin/defaults.nix).
# runs as root in darwin-rebuild switch, act as user with sudo -u.
# args: $1 = username, $2 = mysides binary
set -eu

user="$1"
mysides="$2"

# make sure the screenshots dir exists (screencapture.location point to it)
sudo -u "$user" mkdir -p "/Users/$user/Pictures/Screenshots"

# finder sidebar favorites via mysides. pin ~ and ~/Pictures/Screenshots, drop Documents/Recents.
# remove by name depend on locale (english here), so || true so a mismatch dont fail the switch.
# check the sidebar once after first apply.
sudo -u "$user" "$mysides" remove "$user" >/dev/null 2>&1 || true
sudo -u "$user" "$mysides" add "$user" "file:///Users/$user/" >/dev/null 2>&1 || true
sudo -u "$user" "$mysides" remove "Screenshots" >/dev/null 2>&1 || true
sudo -u "$user" "$mysides" add "Screenshots" "file:///Users/$user/Pictures/Screenshots/" >/dev/null 2>&1 || true
sudo -u "$user" "$mysides" remove "Documents" >/dev/null 2>&1 || true
sudo -u "$user" "$mysides" remove "Recents" >/dev/null 2>&1 || true

# apply new macOS settings now
sudo -u "$user" /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
