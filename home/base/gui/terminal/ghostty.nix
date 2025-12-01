{pkgs, ...}: {
  programs.ghostty = {
    enable = true;
    package =
      if pkgs.stdenv.isDarwin
      then pkgs.hello # pkgs.ghostty is currently broken on darwin
      else pkgs.ghostty; # the stable version

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
