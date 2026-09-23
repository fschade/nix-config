{...}: {
  homebrew = {
    brews = [
      "mole" # deep clean and optimize your mac
    ];

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
      "raycast"
      "betterdisplay"
      "itsycal"
      "via" # keyboard configurator
      "karabiner-elements" # key remaps: ⌥a/o/u umlauts, ⌥n tilde (see home/gui/karabiner)
      "alt-tab" # ⌥Tab window switcher like windows, all windows not just apps

      "macshot" # screenshots + annotation, scroll-capture, gif, ocr, pii redact
      "cap" # screen recording with share links, open source loom

      "orbstack" # container runtime, licensed. docker CLIs are in home/cli/dev.nix
      "bruno" # api client, git-friendly .bru files, open source, no cloud
      "cyberduck"
      "ghostty"
      "zed" # fast native editor, light beside intellij
      "jetbrains-toolbox"
      "beekeeper-studio" # multi-db gui incl postgres, oss
      "switchhosts"

      "element"

      "tolaria" # markdown notes / knowledge base, oss, git-backed

      "bitwarden"
      "firefox"
      "brave-browser"
      "qobuz"
      "roon"
      "libation" # audible library manager, exports owned books to m4b/mp3
      "libreoffice"
      "ddpm" # dell monitor
      "rode-central"
      "rode-virtual-channels"
      "appcleaner"

      "nikitabobko/tap/aerospace"
      "sozercan/repo/kaset" # yt-music
    ];
  };
}
