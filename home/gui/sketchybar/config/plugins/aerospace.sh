#!/usr/bin/env bash
# Highlights the focused aerospace workspace. $1 = this item's workspace id.
# FOCUSED_WORKSPACE is set by aerospace's exec-on-workspace-change trigger; on
# first draw it's empty, so fall back to querying aerospace.
export PATH="/opt/homebrew/bin:$PATH"

FOCUSED="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"

if [ "$1" = "$FOCUSED" ]; then
  sketchybar --set "$NAME" background.drawing=on label.color=0xff1e1e2e
else
  sketchybar --set "$NAME" background.drawing=off label.color=0xffcdd6f4
fi
