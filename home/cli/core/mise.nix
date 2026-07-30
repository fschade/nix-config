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
        # mise's tool bin dirs win PATH over the nix profile, so whatever is
        # pinned here is the `usage` you get, not the one from nixpkgs.
        usage = "3";
      };
    };
  };
}
