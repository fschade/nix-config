{
  self,
  pkgs,
  my,
  ...
}: {
  # touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # system defaults and preferences
  system = {
    primaryUser = my.vars.user.name;
    stateVersion = 6;
    configurationRevision = self.rev or self.dirtyRev or null;

    startup.chime = false;

    defaults = {
      LaunchServices.LSQuarantine = false;

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
      };

      dock = {
        autohide = true;
        mineffect = "suck";
        orientation = "bottom";
        static-only = true;
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
      };
    };
    activationScripts.postActivation = {
      text = ''
        # Activate new macOS settings immediately,
        sudo -u ${my.vars.user.name} /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
      '';
    };
  };
}
