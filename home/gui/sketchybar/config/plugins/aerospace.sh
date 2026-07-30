#!/usr/bin/env bash
# highlight the focused aerospace workspace. $1 = this item workspace id.
# FOCUSED_WORKSPACE comes from the aerospace exec-on-workspace-change trigger,
# on first draw it is empty so we ask aerospace instead.
# redundant with the daemon wrapper, kept so the script also works run by hand
export PATH="/opt/homebrew/bin:$PATH"

FOCUSED="$FOCUSED_WORKSPACE"
if [ -z "$FOCUSED" ] && ! FOCUSED="$(aerospace list-workspaces --focused)"; then
  # aerospace not answering. red on purpose, an unhighlighted item is what a
  # normal workspace switch looks like
  sketchybar --set "$NAME" background.drawing=off label.color=0xfff38ba8 # red
  exit 0
fi

# an exit 0 with empty output leaves everything unhighlighted, taking that
if [ "$1" = "$FOCUSED" ]; then
  sketchybar --set "$NAME" background.drawing=on label.color=0xff1e1e2e
else
  sketchybar --set "$NAME" background.drawing=off label.color=0xffcdd6f4
fi
