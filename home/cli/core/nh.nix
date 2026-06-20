{
  config,
  lib,
  pkgs,
  ...
}: {
  # darwin-rebuild / home-manager switch wrapper n + GC
  programs.nh = {
    enable = true;

    flake = "${config.home.homeDirectory}/.config/nix";

    # Automatic store GC. nh's cleaner uses a systemd timer, so enable it only
    # on Linux; on darwin, GC is handled by nix-darwin (nix.gc).
    clean = lib.mkIf pkgs.stdenv.isLinux {
      enable = true;
      extraArgs = "--keep-since 7d --keep 3";
    };
  };
}
