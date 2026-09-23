{...}: {
  programs.ghostty = {
    enable = true;
    package = null;

    enableZshIntegration = true;
    enableBashIntegration = true;
    installBatSyntax = false;

    settings = {
      font-size = 13;

      macos-option-as-alt = false;

      background-opacity = 0.93;
      background-blur = 10;
    };
  };
}
