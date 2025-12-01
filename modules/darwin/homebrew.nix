{
  config,
  inputs,
  vars,
  ...
}: let
  # zsh dont inherit environment.shellInit, so it needs the brew env too.
  # guarded so a machine without brew yet (fresh bootstrap) dont error on every shell.
  brewShellInit = ''[ -x ${config.homebrew.prefix}/bin/brew ] && eval "$(${config.homebrew.prefix}/bin/brew shellenv)"'';
in {
  environment.shellInit = brewShellInit;
  programs.zsh.shellInit = brewShellInit;

  # homebrew installed and pinned by nix-homebrew, no manual `brew install`.
  # every tap is a pinned flake input, `brew tap` off (mutableTaps = false)
  # so taps cant drift from this config.
  nix-homebrew = {
    enable = true;
    user = vars.user.name;
    autoMigrate = true; # adopt existing /opt/homebrew on first switch
    mutableTaps = false;
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "nikitabobko/homebrew-tap" = inputs.homebrew-nikitabobko;
      "sozercan/homebrew-repo" = inputs.homebrew-sozercan;
      "sane-apps/homebrew-tap" = inputs.homebrew-sane-apps;
    };
  };

  # packages (casks / masApps / brews) added per role and per host.
  homebrew = {
    enable = true;

    # keep nix-darwin tap list in sync with pinned taps above, so the generated
    # Brewfile never point to a tap nix-homebrew didnt provide.
    taps = builtins.attrNames config.nix-homebrew.taps;

    # dont force-upgrade casks that update themselves (auto_updates/:latest).
    # brew decides this per cask, so self-updaters manage themselves and the
    # rest still get upgraded by upgrade = true below. avoids the version fight.
    greedyCasks = false;

    # no `brew update` on each switch. taps are nix-pinned (read-only), so the
    # update is wasted and just makes activation slow.
    global.autoUpdate = false;

    onActivation = {
      cleanup = "zap"; # uninstall anything not in the merged Brewfile
      upgrade = true; # upgrade outdated formulae/casks/mas apps on switch
    };
  };
}
