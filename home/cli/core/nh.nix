{
  lib,
  pkgs,
  ...
}: {
  # darwin-rebuild / home-manager switch wrapper + GC
  programs.nh = {
    enable = true;

    # no hardcoded `flake` path, this config shouldnt assume a checkout location
    # so anyone can clone it. scripts/deploy.sh pass the flake (`.#<host>`).
    # for a bare `nh os switch` set $NH_FLAKE (or pass `nh os switch <path>#<host>`).

    # auto store GC. nh cleaner use a systemd timer, so only on linux.
    # on darwin the GC is done by nix-darwin (nix.gc).
    clean = lib.mkIf pkgs.stdenv.isLinux {
      enable = true;
      extraArgs = "--keep-since 7d --keep 3";
    };
  };
}
