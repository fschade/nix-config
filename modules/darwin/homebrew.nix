{
  config,
  inputs,
  vars,
  ...
}: let
  # guarded so a machine without brew yet (fresh bootstrap) dont error on every shell.
  brewShellInit = ''[ -x ${config.homebrew.prefix}/bin/brew ] && eval "$(${config.homebrew.prefix}/bin/brew shellenv)"'';
in {
  # lands in both /etc/bashrc and /etc/zshrc. environment.shellInit looks like
  # the right option but on darwin only the fish module reads it, so bash gets nothing.
  environment.interactiveShellInit = brewShellInit;

  # no usage telemetry from user-invoked brew (activation is covered below)
  environment.variables.HOMEBREW_NO_ANALYTICS = "1";

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

    # sets HOMEBREW_NO_AUTO_UPDATE in the shell env, so a manual `brew install`
    # never auto-updates taps first. the activation bundle is covered separately,
    # onActivation.autoUpdate already defaults to false. taps are nix-pinned
    # (read-only) so the update would just fail or waste time.
    global.autoUpdate = false;

    onActivation = {
      cleanup = "zap"; # uninstall anything not in the merged Brewfile
      upgrade = true; # upgrade outdated formulae/casks/mas apps on switch
      extraEnv.HOMEBREW_NO_ANALYTICS = "1"; # activation runs under sudo, no shell env
    };
  };
}
