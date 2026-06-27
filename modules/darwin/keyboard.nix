{...}: {
  system = {
    # Caps Lock → Control: frees prime real estate for terminal/editor chords
    # (Ctrl+C, Ctrl+R, Ctrl+A) without pinky strain.
    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = true;
    };

    defaults.NSGlobalDomain = {
      # Fast key repeat for moving through code (UI minimums).
      KeyRepeat = 2; # repeat speed — lower is faster
      InitialKeyRepeat = 15; # delay before repeat starts — lower is shorter

      # Hold a key to repeat it (e.g. vim hjkl) instead of the accent popup.
      ApplePressAndHoldEnabled = false;

      # Top row acts as real F1-F12; use fn+key for brightness/volume/media.
      "com.apple.keyboard.fnState" = true;
    };

    # Force the U.S. keyboard layout as the only input source (all Macs).
    # On U.S.: `~` is Shift+backtick (top-left, under Esc), and umlauts are
    # Option+u then the vowel → ä ö ü, Option+s → ß. (May need a re-login to
    # take effect; if `~` still needs Fn, that's your VIA keyboard firmware,
    # not macOS — remap it there.)
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
