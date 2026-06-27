{...}: {
  # Determinate manages the Nix installation with its own daemon, which
  # conflicts with nix-darwin's native Nix management, so disable it here.
  #   https://github.com/LnL7/nix-darwin/issues/149
  nix.enable = false;

  # Disable auto-optimise-store because of this issue:
  #   https://github.com/NixOS/nix/issues/7273
  nix.settings.auto-optimise-store = false;
  nix.gc.automatic = false;

  # Effective on platforms where nix-darwin manages nix.conf (no-op under
  # Determinate, which enables flakes itself). Note: lazy-trees is a *setting*
  # (lazy-trees = true), not an experimental feature — don't list it here.
  nix.settings.experimental-features = ["nix-command" "flakes"];

  nixpkgs.config.allowUnfree = true;
}
