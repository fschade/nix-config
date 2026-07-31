{
  lib,
  pkgs,
  ...
}: {
  # darwin-rebuild / home-manager switch wrapper + GC
  programs.nh = {
    enable = true;

    # no hardcoded `flake` path, this config shouldnt assume a checkout location.
    # for a bare `nh os switch` set $NH_FLAKE, or pass `<path>#<host>`.

    # auto store GC, linux only. the module would wire a launchd agent on darwin
    # too, but determinate owns the daemon there, so GC runs via `mise run gc`.
    clean = lib.mkIf pkgs.stdenv.isLinux {
      enable = true;
      extraArgs = "--keep-since 7d --keep 3";
    };
  };
}
