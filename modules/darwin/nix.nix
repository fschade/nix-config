{...}: {
  # determinate runs nix with its own daemon, clashes with nix-darwin native
  # nix management, so turn it off here.
  #   https://github.com/LnL7/nix-darwin/issues/149
  nix.enable = false;

  # auto-optimise-store off because of this issue:
  #   https://github.com/NixOS/nix/issues/7273
  nix.settings.auto-optimise-store = false;
  nix.gc.automatic = false;

  # only matters where nix-darwin manages nix.conf (no-op under determinate,
  # it enables flakes itself). note: lazy-trees is a setting (lazy-trees = true),
  # not an experimental feature, dont list it here.
  nix.settings.experimental-features = ["nix-command" "flakes"];

  nixpkgs.config.allowUnfree = true;
}
