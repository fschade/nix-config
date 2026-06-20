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
      };

      env.MISE_NODE_COREPACK = "true";

      # Pinned for reproducibility across machines — `latest` drifts and
      # undermines the whole point of a declarative setup. Bump deliberately.
      tools = {
        node = "22";
        pnpm = "10";
        go = "1.24";
        rust = "stable";
      };
    };
  };
}
