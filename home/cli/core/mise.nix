{...}: {
  programs.mise = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;

    globalConfig = {
      settings = {
        experimental = true;
        verbose = false;
        auto_install = true;
        idiomatic_version_file_enable_tools = [];
        node.corepack = true;
      };

      tools = {
        node = "26";
        pnpm = "12";
        go = "1.27";
        rust = "stable";
        usage = "3";
      };
    };
  };
}
