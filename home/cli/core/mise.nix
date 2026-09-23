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
        pnpm = "11";
        go = "1.26";
        rust = "stable";
        usage = "3";
      };
    };
  };
}
