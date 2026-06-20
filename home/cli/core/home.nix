{pkgs, ...}: {
  # The Home Manager release this config is compatible with. Update only when
  # you follow the release notes.
  home.stateVersion = "26.05";

  # Manage XDG base directories.
  xdg.enable = true;

  # For security reasons, do not load neovim's user config since EDITOR may be
  # used to edit some critical files. The wrapper keeps --clean while exposing
  # EDITOR as a single executable, so tools that exec it directly (no shell)
  # don't choke on the argument. nvim comes from core packages.
  home.sessionVariables.EDITOR = "${pkgs.writeShellScript "editor" ''
    exec ${pkgs.neovim}/bin/nvim --clean "$@"
  ''}";

  # Extra dirs prepended to PATH (applied across bash/zsh).
  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  # Don't build the home-manager option manpages — rendering them pulls in the
  # nixpkgs options doc and triggers a noisy `options.json … without a proper
  # context` eval warning.
  manual.manpages.enable = false;
}
