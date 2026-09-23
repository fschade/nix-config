{...}: {
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
}
