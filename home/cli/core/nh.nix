{
  lib,
  pkgs,
  ...
}: {
  # darwin-rebuild / home-manager switch wrapper n + GC
  programs.nh = {
    enable = true;

    # No hardcoded `flake` path — this config shouldn't assume a checkout
    # location (portable for anyone cloning it). The flake is passed explicitly
    # by scripts/deploy.sh (`.#<host>`); for a bare `nh os switch`, set the
    # $NH_FLAKE env var (or pass `nh os switch <path>#<host>`).

    # Automatic store GC. nh's cleaner uses a systemd timer, so enable it only
    # on Linux; on darwin, GC is handled by nix-darwin (nix.gc).
    clean = lib.mkIf pkgs.stdenv.isLinux {
      enable = true;
      extraArgs = "--keep-since 7d --keep 3";
    };
  };
}
