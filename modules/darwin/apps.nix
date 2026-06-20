{...}: {
  homebrew = {
    taps = [
      "nikitabobko/tap"
      "sozercan/repo" # kaset
    ];

    brews = [
      "mole" # deep clean and optimize your Mac
    ];

    # Mac App Store apps (via mas). They must be installed manually once so your
    # Apple account has a record of them, otherwise the store refuses.
    masApps = {
      "Xcode" = 497799835;
      "The Unarchiver" = 425424353;
      "Affinity Photo" = 824183456;
      "Affinity Designer" = 824171161;
      "Affinity Publisher" = 881418622;
      "Keynote" = 409183694;
      "Pages" = 409201541;
      "Numbers" = 409203825;
      "Signal Shifter" = 6446061552;
      "Amphetamine" = 937984704;
      "Blackmagic Disk Speed Test" = 425264550;
      "DaisyDisk" = 411643860;
    };

    casks = [
      # OS enhancements
      "hiddenbar"
      "raycast"
      "betterdisplay"
      "itsycal"
      "via" # keyboard configurator

      ## dev
      "docker-desktop"
      "cyberduck"
      "ghostty"
      "visual-studio-code"
      "jetbrains-toolbox"
      "sequel-ace"
      "switchhosts"

      ## messaging
      "element"

      ## other
      "bitwarden"
      "firefox"
      "brave-browser"
      "qobuz"
      "roon"
      "libreoffice"
      "ddpm" # dell monitor
      "rode-central"
      "rode-virtual-channels"
      "appcleaner"

      # Casks from non-official taps. We trust the specific cask rather than the
      # whole tap; per-cask trust only applies to fully-qualified names
      # (user/tap/cask). See https://docs.brew.sh/Tap-Trust.
      {
        name = "nikitabobko/tap/aerospace";
        trusted = true;
      }
      {
        name = "sozercan/repo/kaset"; # yt-music
        trusted = true;
      }
    ];
  };
}
