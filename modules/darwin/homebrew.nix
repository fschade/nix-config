{
  config,
  inputs,
  vars,
  ...
}: let
  # zsh doesn't inherit environment.shellInit, so it needs the brew env too.
  # Guarded so a machine without brew yet (fresh bootstrap, before nix-homebrew
  # has run) doesn't error on every shell.
  brewShellInit = ''[ -x ${config.homebrew.prefix}/bin/brew ] && eval "$(${config.homebrew.prefix}/bin/brew shellenv)"'';
in {
  environment.shellInit = brewShellInit;
  programs.zsh.shellInit = brewShellInit;

  # Homebrew is installed and pinned declaratively by nix-homebrew — no manual
  # `brew install` bootstrap. Every tap is a pinned flake input; `brew tap` is
  # disabled (mutableTaps = false) so taps can't drift from this config.
  nix-homebrew = {
    enable = true;
    user = vars.user.name;
    autoMigrate = true; # adopt an existing /opt/homebrew on first switch
    mutableTaps = false;
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "nikitabobko/homebrew-tap" = inputs.homebrew-nikitabobko;
      "sozercan/homebrew-repo" = inputs.homebrew-sozercan;
    };
  };

  # Packages (casks / masApps / brews) are added per role and per host.
  homebrew = {
    enable = true;

    # Keep nix-darwin's tap list exactly in sync with the pinned taps above, so
    # the generated Brewfile never references a tap nix-homebrew didn't provide.
    taps = builtins.attrNames config.nix-homebrew.taps;

    greedyCasks = true; # also upgrade casks that auto-update (brew's --greedy)

    onActivation = {
      cleanup = "zap"; # uninstall anything not listed in the merged Brewfile
      upgrade = true; # upgrade outdated formulae/casks/mas apps on switch
    };
  };
}
