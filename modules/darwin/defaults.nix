{
  pkgs,
  vars,
  ...
}: {
  system = {
    startup.chime = false;

    defaults = {
      LaunchServices.LSQuarantine = false;

      # Require the password immediately after screen saver / sleep.
      screensaver = {
        askForPassword = true;
        askForPasswordDelay = 0;
      };

      controlcenter = {
        BatteryShowPercentage = true;
        Bluetooth = true;
        Sound = true;
      };

      loginwindow = {
        GuestEnabled = false;
        DisableConsoleAccess = true;
      };

      finder = {
        AppleShowAllFiles = true; # hidden files
        AppleShowAllExtensions = true; # file extensions
        _FXShowPosixPathInTitle = true; # title bar full path
        ShowPathbar = true; # breadcrumb nav at bottom
        ShowStatusBar = true; # file count & disk space
        FXEnableExtensionChangeWarning = false; # no nag when renaming extensions
        _FXSortFoldersFirst = true; # folders before files
        FXPreferredViewStyle = "Nlsv"; # list view by default
      };

      dock = {
        autohide = true;
        autohide-delay = 0.0; # no delay before the Dock slides in
        autohide-time-modifier = 0.0; # no slide animation
        mineffect = "suck";
        orientation = "bottom";
        static-only = true; # only show running apps
        show-recents = false; # no recent-apps section
        mru-spaces = false; # don't auto-reorder Spaces by use (for aerospace)
      };

      screencapture = {
        location = "/Users/${vars.user.name}/Screenshots"; # not the Desktop
        type = "png";
        disable-shadow = true; # no drop shadow on window captures
      };

      iCal = {
        "TimeZone support enabled" = true;
        "first day of week" = "Monday";
      };

      menuExtraClock = {
        Show24Hour = true;
        ShowDate = 1;
      };

      CustomUserPreferences = {
        # Thaw (menu-bar manager) behaviour. NOTE: *which* icons are hidden is
        # machine-specific (menu-bar item positions + opaque blobs) → set once
        # per machine by ⌘-dragging the separator; not declarable here.
        "com.stonerl.Thaw" = {
          AutoRehide = true; # re-hide the extra icons automatically
          HideApplicationMenus = true; # reclaim space from the app menus
          EnableAlwaysHiddenSection = false;
          EnableSecondaryContextMenu = true;
        };
        "com.apple.finder" = {
          ShowRecentTags = false; # hide the Tags section in the Finder sidebar
        };
        "com.apple.symbolichotkeys" = {
          AppleSymbolicHotKeys = {
            # disable 'cmd + space' for spotlight Search
            "64" = {
              enabled = false;
            };
          };
        };
        "com.raycast.macos" = {
          # enable 'cmd + space' for raycast search
          raycastGlobalHotkey = "Command-49";
        };
      };

      NSGlobalDomain = {
        NSAutomaticSpellingCorrectionEnabled = false;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticWindowAnimationsEnabled = false;
        AppleICUForce24HourTime = true;
        AppleInterfaceStyle = "Dark";
        AppleMeasurementUnits = "Centimeters";
        AppleMetricUnits = 1;
        AppleShowAllExtensions = true;
        AppleTemperatureUnit = "Celsius";
        AppleKeyboardUIMode = 3; # full keyboard access — Tab through all controls
        NSNavPanelExpandedStateForSaveMode = true; # expanded save dialogs
      };
    };

    activationScripts.postActivation.text = ''
      # Hold the screenshots target dir referenced by screencapture.location.
      sudo -u ${vars.user.name} mkdir -p /Users/${vars.user.name}/Screenshots

      # Finder sidebar favorites (mysides). Best-effort + idempotent: pin ~ and
      # ~/Screenshots; drop Documents/Recents. Remove-by-name is locale-sensitive
      # (English defaults) — the `|| true` keeps a name mismatch from failing the
      # switch; eyeball the sidebar once after first apply.
      mysides=${pkgs.mysides}/bin/mysides
      sudo -u ${vars.user.name} "$mysides" remove "${vars.user.name}" >/dev/null 2>&1 || true
      sudo -u ${vars.user.name} "$mysides" add "${vars.user.name}" "file:///Users/${vars.user.name}/" >/dev/null 2>&1 || true
      sudo -u ${vars.user.name} "$mysides" remove "Screenshots" >/dev/null 2>&1 || true
      sudo -u ${vars.user.name} "$mysides" add "Screenshots" "file:///Users/${vars.user.name}/Screenshots/" >/dev/null 2>&1 || true
      sudo -u ${vars.user.name} "$mysides" remove "Documents" >/dev/null 2>&1 || true
      sudo -u ${vars.user.name} "$mysides" remove "Recents" >/dev/null 2>&1 || true

      # Activate new macOS settings immediately
      sudo -u ${vars.user.name} /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    '';
  };
}
