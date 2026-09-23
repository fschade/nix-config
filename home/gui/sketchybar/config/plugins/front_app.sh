#!/usr/bin/env bash
if [ "$SENDER" = "front_app_switched" ]; then
  map="$CONFIG_DIR/plugins/icon_map.sh"
  if [ -r "$map" ]; then
    # shellcheck source=/dev/null
    source "$map"
    __icon_map "$INFO"
    # shellcheck disable=SC2154
    sketchybar --set "$NAME" label="$INFO" icon="$icon_result"
  else
    sketchybar --set "$NAME" label="$INFO"
  fi
fi
