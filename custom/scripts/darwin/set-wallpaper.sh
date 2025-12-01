#!/usr/bin/env bash
# set desktop wallpaper with desktoppr (see home/gui/wallpaper.nix, runs as
# home-manager activation step after writeBoundary). || true so a headless/SSH
# switch (no GUI session) dont fail.
# args: $1 = desktoppr binary, $2 = image path, $3 = hex color, $4 = scale
set -u

desktoppr="$1"
path="$2"
color="$3"
scale="$4"

"$desktoppr" all "$path" || true
sleep 1
"$desktoppr" color "$color" || true
sleep 1
"$desktoppr" scale "$scale" || true
