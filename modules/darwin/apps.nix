{
  config,
  lib,
  pkgs,
  ...
}: {
  # Install packages from nix's official package repository.
  #
  # The packages installed here are available to all users, and are reproducible across machines, and are rollbackable.
  # But on macOS, it's less stable than homebrew.
  #
  # Related Discussion: https://discourse.nixos.org/t/darwin-again/29331
  environment.systemPackages = with pkgs; [
    neovim
    git
    nushell # my custom shell
  ];

  # homebrew need to be installed manually, see https://brew.sh
  # https://github.com/LnL7/nix-darwin/blob/master/modules/homebrew.nix
  homebrew = {
    enable = true; # disable homebrew for fast deploy

    onActivation = {
      autoUpdate = true; # Fetch the newest stable branch of Homebrew's git repo
      upgrade = true; # Upgrade outdated casks, formulae, and App Store apps
      # 'zap': uninstalls all formulae(and related files) not listed in the generated Brewfile
      cleanup = "zap";
    };

    # Applications to install from Mac App Store using mas.
    # You need to install all these Apps manually first so that your apple account have records for them.
    # otherwise Apple Store will refuse to install them.
    # For details, see https://github.com/mas-cli/mas
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

    taps = [
      "nikitabobko/tap"
      "sozercan/repo" # kaset
    ];

    brews = [
      "mole" # deep clean and optimize your Mac.
    ];

    casks = [
      # OS enhancements
      "aerospace"
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
      "sozercan/repo/kaset" # yt-music
    ];
  };
}
