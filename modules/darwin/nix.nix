{...}: {
  # determinate runs nix with its own daemon, clashes with nix-darwin native nix
  # management, so turn it off here. that gates all of nix.conf too, so
  # nix.settings would silently do nothing. determinate enables flakes itself.
  #   https://github.com/nix-darwin/nix-darwin/issues/149
  nix.enable = false;

  # standalone home-manager builds its own pkgs, it sets this again in flake.nix mkHome
  nixpkgs.config.allowUnfree = true;
}
