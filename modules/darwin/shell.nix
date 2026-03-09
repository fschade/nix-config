{ config, ... }:
let
  brewShellInit = ''
    eval "$(${config.homebrew.prefix}/bin/brew shellenv)"
  '';
in
{
  environment.shellInit = brewShellInit;
  programs.zsh.shellInit = brewShellInit; # `zsh` doesn't inherit `environment.shellInit`
}
