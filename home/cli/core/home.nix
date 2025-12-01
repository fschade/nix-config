{pkgs, ...}: {
  # Home Manager release this config match. only bump when you read release notes.
  home.stateVersion = "26.05";

  # manage XDG base dirs.
  xdg.enable = true;

  # security: dont load neovim user config, EDITOR may edit critical files.
  # the wrapper keeps --clean but exposes EDITOR as one executable, so tools
  # that exec it directly (no shell) dont choke on the arg. nvim from core packages.
  home.sessionVariables.EDITOR = "${pkgs.writeShellScript "editor" ''
    exec ${pkgs.neovim}/bin/nvim --clean "$@"
  ''}";

  # extra dirs added to PATH (bash + zsh).
  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  # dont build the home-manager option manpages, rendering them pulls the
  # nixpkgs options doc and gives a noisy `options.json … without a proper
  # context` eval warning.
  manual.manpages.enable = false;
}
