{
  config,
  inputs,
  vars,
  ...
}: let
  brewShellInit = ''[ -x ${config.homebrew.prefix}/bin/brew ] && eval "$(${config.homebrew.prefix}/bin/brew shellenv)"'';
in {
  environment.interactiveShellInit = brewShellInit;

  environment.variables.HOMEBREW_NO_ANALYTICS = "1";

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

  homebrew = {
    enable = true;

    taps = builtins.attrNames config.nix-homebrew.taps;

    greedyCasks = false;

    global.autoUpdate = false;

    onActivation = {
      cleanup = "zap"; # uninstall anything not in the merged Brewfile
      upgrade = true; # upgrade outdated formulae/casks/mas apps on switch
      extraEnv.HOMEBREW_NO_ANALYTICS = "1"; # activation runs under sudo, no shell env
    };
  };
}
