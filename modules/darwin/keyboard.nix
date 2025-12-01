{...}: {
  system = {
    # caps lock to control, better for terminal/editor chords, no pinky strain
    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = true;
    };

    defaults.NSGlobalDomain = {
      # fast key repeat for moving through code, ui minimums
      KeyRepeat = 2; # repeat speed, lower is faster
      InitialKeyRepeat = 15; # delay before repeat, lower is shorter

      # hold key to repeat (like vim hjkl) instead of accent popup
      ApplePressAndHoldEnabled = false;

      # top row is real f1-f12, use fn+key for brightness/volume/media
      "com.apple.keyboard.fnState" = true;
    };

    # force U.S. layout as only input source on all macs.
    # on U.S.: `~` is shift+backtick (top-left under esc), umlauts are
    # option+u then vowel = ä ö ü, option+s = ß. may need re-login.
    # if `~` still need fn, thats your VIA firmware not macos, remap it there.
    defaults.CustomUserPreferences."com.apple.HIToolbox" = {
      AppleEnabledInputSources = [
        {
          InputSourceKind = "Keyboard Layout";
          "KeyboardLayout ID" = 0;
          "KeyboardLayout Name" = "U.S.";
        }
      ];
      AppleCurrentKeyboardLayoutInputSourceID = "com.apple.keylayout.US";
    };
  };
}
