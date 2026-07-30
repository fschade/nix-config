{pkgs, ...}: {
  # home-manager release this config match. only bump when you read release notes.
  home.stateVersion = "26.05";

  xdg.enable = true;

  # security: dont load neovim user config, EDITOR may edit critical files.
  # the wrapper keeps --clean but exposes EDITOR as one executable, so tools
  # that exec it directly (no shell) dont choke on the arg.
  # your interactive nvim is the one from packages.nix, this wrapper is only EDITOR
  home.sessionVariables.EDITOR = "${pkgs.writeShellScript "editor" ''
    exec ${pkgs.neovim}/bin/nvim --clean "$@"
  ''}";

  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  # dont build the home-manager option manpages, rendering them pulls the
  # nixpkgs options doc and gives a noisy `options.json ... without a proper
  # context` eval warning.
  manual.manpages.enable = false;
}
