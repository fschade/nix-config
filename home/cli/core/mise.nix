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
        node = "26";
        pnpm = "11";
        go = "1.26";
        rust = "stable";
        # nixpkgs caps `usage` at 3.2.1; mise ships newer and its tool bin
        # dirs take PATH priority over the nix profile, so this wins.
        usage = "3";
      };
    };
  };
}
