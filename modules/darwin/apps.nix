{...}: {
  homebrew = {
    # Taps are declared/pinned in homebrew.nix via nix-homebrew.
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
      "thaw" # menu-bar manager (maintained successor to Ice / Hidden Bar)
      "raycast"
      "betterdisplay"
      "itsycal"
      "via" # keyboard configurator

      ## screenshots / recording
      "macshot" # screenshots + annotation, scroll-capture, GIF, OCR, PII auto-redact
      "cap" # screen recording with share links (open-source Loom alternative)

      ## dev
      # container runtime is colima (see home/cli/dev.nix), not Docker Desktop
      "bruno" # API client — git-friendly (.bru files), open source, no cloud/account
      "cyberduck"
      "ghostty"
      "zed" # fast native editor — lightweight complement to IntelliJ
      "jetbrains-toolbox"
      "beekeeper-studio" # multi-DB GUI (incl. Postgres) — OSS; replaces MySQL-only Sequel Ace
      "switchhosts"

      ## messaging
      "element"

      ## notes
      "tolaria" # markdown knowledge base / notes — OSS, git-backed, actively maintained

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
