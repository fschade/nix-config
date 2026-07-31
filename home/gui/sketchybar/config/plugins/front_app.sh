#!/usr/bin/env bash
if [ "$SENDER" = "front_app_switched" ]; then
  # the label is always right; the icon needs the map, so a missing map degrades
  # to a labelled item instead of a blank icon plus errors into a log nobody reads.
  map="$CONFIG_DIR/plugins/icon_map.sh"
  if [ -r "$map" ]; then
    # shellcheck source=/dev/null
    source "$map"
    __icon_map "$INFO"
    # icon_result is set by __icon_map in the sourced map
    # shellcheck disable=SC2154
    sketchybar --set "$NAME" label="$INFO" icon="$icon_result"
  else
    sketchybar --set "$NAME" label="$INFO"
  fi
fi
