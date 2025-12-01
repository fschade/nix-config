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

      # pinned so its reproducible across machines. `latest` drifts and kills
      # the point of a declarative setup. bump on purpose.
      tools = {
        node = "26";
        pnpm = "11";
        go = "1.26";
        rust = "stable";
        # nixpkgs caps `usage` at 3.2.1, mise ships newer and its tool bin
        # dirs win PATH over the nix profile, so this one wins.
        usage = "3";
      };
    };
  };
}
