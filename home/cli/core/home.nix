{pkgs, ...}: {
  home.stateVersion = "26.05";

  xdg.enable = true;

  home.sessionVariables.EDITOR = "${pkgs.writeShellScript "editor" ''
    exec ${pkgs.neovim}/bin/nvim --clean "$@"
  ''}";

  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  manual.manpages.enable = false;
}
