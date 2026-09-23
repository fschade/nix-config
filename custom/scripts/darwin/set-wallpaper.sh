#!/usr/bin/env bash
set -eu

desktoppr="$1"
path="$2"
color="$3"
scale="$4"

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
sleep 1
"$desktoppr" color "$color" || true
sleep 1
"$desktoppr" scale "$scale" || true
