-- template, the builder fills the __PLACEHOLDER__ values before running it.
-- lays the mounted volume out over finder: hide the chrome, set the window +
-- icon size, drop the background picture and place the icons on their frames.
-- the background is a relative HFS reference so it survives the volume rename,
-- a POSIX/absolute path would point at the throwaway mount.
tell application "Finder"
  tell disk "__VOLUME__"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {300, 160, __RIGHT__, __BOTTOM__}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 128
    set background picture of opts to file ".background:__BG__"
    set position of item "__APP__" of container window to {__APP_X__, __APP_Y__}
    set position of item "Applications" of container window to {__APPS_X__, __APPS_Y__}
    try
      set position of item "__README__" of container window to {__README_X__, __README_Y__}
    end try
    update without registering applications
    delay 1
    close
  end tell
end tell
