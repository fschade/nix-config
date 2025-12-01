#!/usr/bin/env bash
# focused app: name + a glyph icon from icon_map
if [ "$SENDER" = "front_app_switched" ]; then
  # shellcheck source=/dev/null
  source "$CONFIG_DIR/plugins/icon_map.sh"
  __icon_map "$INFO"
  sketchybar --set "$NAME" label="$INFO" icon="$icon_result"
fi
