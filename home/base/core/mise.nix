{ pkgs
, lib
, ...
}: {
  programs.mise = {
    enable = true;
    enableZshIntegration = true;

    globalConfig = {
      settings = {
        experimental = true;
        verbose = false;
        auto_install = true;
        idiomatic_version_file_enable_tools = [ ];
      };

      env = {
        MISE_NODE_COREPACK = "true";
      };

      tools = {
        node = "latest";
        pnpm = "latest";
        go = "latest";
        rust = "latest";
      };
    };
  };
}
