#!/usr/bin/env bash
# Focused app: name + an app-font glyph icon (via the bundled icon_map).
if [ "$SENDER" = "front_app_switched" ]; then
  # shellcheck source=/dev/null
  source "$CONFIG_DIR/plugins/icon_map.sh"
  __icon_map "$INFO"
  sketchybar --set "$NAME" label="$INFO" icon="$icon_result"
fi
