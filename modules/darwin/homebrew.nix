{config, ...}: let
  # zsh doesn't inherit environment.shellInit, so it needs the brew env too.
  brewShellInit = ''eval "$(${config.homebrew.prefix}/bin/brew shellenv)"'';
in {
  environment.shellInit = brewShellInit;
  programs.zsh.shellInit = brewShellInit;

  # homebrew itself must be installed manually first, see https://brew.sh
  # Packages (casks / masApps / brews / taps) are added per role and per host.
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true; # fetch the newest stable branch of Homebrew's git repo
      upgrade = true; # upgrade outdated casks, formulae, and App Store apps
      cleanup = "zap"; # uninstall anything not listed in the merged Brewfile
    };
  };
}
