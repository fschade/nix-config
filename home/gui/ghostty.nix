{pkgs, ...}: {
  programs.ghostty = {
    enable = true;
    # pkgs.ghostty is currently broken on darwin; Ghostty itself is installed
    # via Homebrew cask, so this only manages its config. The dummy package
    # keeps home-manager happy without building ghostty from nixpkgs.
    package = pkgs.hello;

    enableZshIntegration = true;
    enableBashIntegration = true;
    installBatSyntax = false;

    settings = {
      font-size = 13;

      background-opacity = 0.93;
      # only supported on macOS;
      background-blur-radius = 10;
      scrollback-limit = 20000;
    };
  };
}
