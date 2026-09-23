#!/usr/bin/env bash
export PATH="/opt/homebrew/bin:$PATH"

# shellcheck source=colors.sh
source "$CONFIG_DIR/plugins/colors.sh" # BASE, TEXT, RED

FOCUSED="$FOCUSED_WORKSPACE"
if [ -z "$FOCUSED" ] && ! FOCUSED="$(aerospace list-workspaces --focused)"; then
  sketchybar --set "$NAME" background.drawing=off label.color=$RED
  exit 0
fi

if [ "$1" = "$FOCUSED" ]; then
  sketchybar --set "$NAME" background.drawing=on label.color=$BASE
else
  sketchybar --set "$NAME" background.drawing=off label.color=$TEXT
fi
