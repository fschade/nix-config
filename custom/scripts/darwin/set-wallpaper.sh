#!/usr/bin/env bash
# set desktop wallpaper with desktoppr (see home/gui/wallpaper.nix, runs as
# home-manager activation step after writeBoundary). `|| true` so a headless/SSH
# switch without GUI session dont fail.
# args: $1 = desktoppr binary, $2 = image path, $3 = hex color, $4 = scale
set -u

desktoppr="$1"
path="$2"
color="$3"
scale="$4"

# a bad image, color or scale is a config bug and has to fail here: `desktoppr
# all` with a missing file only exits 1 and so does a color it cannot parse,
# which the `|| true` below eats, and `desktoppr scale` with a value it dont know
# exits 0 and just prints the current one. accepted values are from
# `desktoppr help`.
if [ ! -f "$path" ]; then
  echo "set-wallpaper: no image at $path" >&2
  exit 1
fi
case "$color" in
  [0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) ;;
  *)
    echo "set-wallpaper: color is '$color', expected six hex digits like 000000" >&2
    exit 1
    ;;
esac
case "$scale" in
  fill | stretch | center | fit) ;;
  *)
    echo "set-wallpaper: scale is '$scale', expected fill, stretch, center or fit" >&2
    exit 1
    ;;
esac

"$desktoppr" all "$path" || true
# back to back calls dont always take, the process behind the wallpaper needs a
# moment to catch up. the sleeps are straight from desktoppr's readme
sleep 1
"$desktoppr" color "$color" || true
sleep 1
"$desktoppr" scale "$scale" || true
