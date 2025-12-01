{
  pkgs,
  config,
  ...
}: {
  nix.settings = {
    # enable flakes globally
    experimental-features = [
      "lazy-trees"
      "nix-command"
      "flakes"
    ];
  };

  nixpkgs.config.allowUnfree = true;
}
