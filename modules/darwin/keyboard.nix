{...}: {
  system = {
    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = true;
    };

    defaults.NSGlobalDomain = {
      KeyRepeat = 2; # repeat speed, lower is faster
      InitialKeyRepeat = 15; # delay before repeat, lower is shorter

      ApplePressAndHoldEnabled = false;

      "com.apple.keyboard.fnState" = true;
    };

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
