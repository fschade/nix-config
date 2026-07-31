{...}: {
  homebrew = {
    # taps are pinned in homebrew.nix via nix-homebrew.
    brews = [
      "mole" # deep clean and optimize your mac
    ];

    # mac app store apps via mas. install once by hand so your apple account
    # has a record, else the store refuse it.
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
      "Windows App" = 1295203466; # rdp client
    };

    casks = [
      # OS enhancements
      "raycast"
      "betterdisplay"
      "itsycal"
      "via" # keyboard configurator
      "karabiner-elements" # key remaps: ⌥a/o/u umlauts, ⌥n tilde (see home/gui/karabiner)
      "alt-tab" # ⌥Tab window switcher like windows, all windows not just apps

      ## screenshots / recording
      "macshot" # screenshots + annotation, scroll-capture, gif, ocr, pii redact
      "cap" # screen recording with share links, open source loom

      ## dev
      # container runtimes: colima is primary (see home/cli/dev.nix), orbstack
      # is there too. switch with `docker-use-colima` / `docker-use-orb` /
      # `docker-use-status`. none is docker desktop.
      "orbstack" # fast docker/linux vm
      "bruno" # api client, git-friendly .bru files, open source, no cloud
      "cyberduck"
      "ghostty"
      "zed" # fast native editor, light beside intellij
      "jetbrains-toolbox"
      "beekeeper-studio" # multi-db gui incl postgres, oss
      "switchhosts"

      ## messaging
      "element"

      ## notes
      "tolaria" # markdown notes / knowledge base, oss, git-backed

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
      "puremac" # open-source app manager + system cleaner

      # casks from non-official taps. the full name user/tap/cask is what scopes
      # trust to the single cask instead of the whole tap (trusted is on by
      # default). https://docs.brew.sh/Tap-Trust
      "nikitabobko/tap/aerospace"
      "sozercan/repo/kaset" # yt-music
    ];
  };
}
