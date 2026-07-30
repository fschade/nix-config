#!/usr/bin/env bash
if [ "$SENDER" = "front_app_switched" ]; then
  # shellcheck source=/dev/null
  source "$CONFIG_DIR/plugins/icon_map.sh"
  __icon_map "$INFO"
  # icon_result is set by __icon_map in the sourced icon_map.sh
  # shellcheck disable=SC2154
  sketchybar --set "$NAME" label="$INFO" icon="$icon_result"
fi
