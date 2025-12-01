{
  pkgs,
  vars,
  ...
}: {
  system = {
    startup.chime = false;

    defaults = {
      LaunchServices.LSQuarantine = false;

      # ask password right after screensaver or sleep
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
        _FXShowPosixPathInTitle = true; # title bar full path
        ShowPathbar = true; # breadcrumb nav at bottom
        ShowStatusBar = true; # file count & disk space
        FXEnableExtensionChangeWarning = false; # no nag when rename extension
        _FXSortFoldersFirst = true; # folders before files
        FXPreferredViewStyle = "Nlsv"; # list view by default
        FXDefaultSearchScope = "SCcf"; # search current folder, not whole mac
      };

      dock = {
        autohide = true;
        autohide-delay = 0.0; # no delay before dock slide in
        autohide-time-modifier = 0.0; # no slide animation
        mineffect = "suck";
        orientation = "bottom";
        static-only = true; # only show running apps
        show-recents = false; # no recent apps section
        mru-spaces = false; # dont reorder spaces by use, for aerospace

        # hot corners off (1 = no action), no accident with mission control
        wvous-tl-corner = 1;
        wvous-tr-corner = 1;
        wvous-bl-corner = 1;
        wvous-br-corner = 1;
      };

      trackpad = {
        Clicking = true; # tap-to-click
      };

      screencapture = {
        location = "/Users/${vars.user.name}/Pictures/Screenshots"; # not the desktop
        type = "png";
        disable-shadow = true; # no drop shadow on window capture
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
        # menu-bar manager is SaneBar (cask in apps.nix). which icons are hidden
        # is per machine, set once in the SaneBar UI, cant declare it here.
        "com.apple.finder" = {
          ShowRecentTags = false; # hide tags section in finder sidebar
        };
        "com.apple.loginwindow" = {
          TALLogoutSavesState = false; # no reopen apps after restart, clean state
        };
        "com.apple.desktopservices" = {
          # no .DS_Store on network or usb volumes, keeps repos clean
          DSDontWriteNetworkStores = true;
          DSDontWriteUSBStores = true;
        };
        "com.apple.spaces" = {
          "spans-displays" = true; # one workspace over all displays, for aerospace multi-monitor
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
        AppleKeyboardUIMode = 3; # full keyboard access, tab through all controls
        NSNavPanelExpandedStateForSaveMode = true; # expanded save dialogs
        PMPrintingExpandedStateForPrint = true; # expanded print dialogs
        NSWindowResizeTime = 0.001; # near instant window resize, fits no-animation setup
        AppleShowScrollBars = "Always"; # scrollbars always visible
        NSAutomaticQuoteSubstitutionEnabled = false; # no smart quotes, they break code
        NSAutomaticDashSubstitutionEnabled = false; # no en/em-dash substitution
        "com.apple.mouse.tapBehavior" = 1; # tap-to-click global, also login window
      };
    };

    # user-side reconcile after activation: screenshots dir, finder sidebar,
    # settings reload. script lives in custom/scripts/, values passed in.
    activationScripts.postActivation.text = ''
      ${pkgs.bash}/bin/bash ${../../custom/scripts/darwin/defaults-postactivation.sh} "${vars.user.name}" "${pkgs.mysides}/bin/mysides"
    '';
  };
}
