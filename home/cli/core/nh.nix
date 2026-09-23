{
  lib,
  pkgs,
  ...
}: {
  programs.nh = {
    enable = true;

    clean = lib.mkIf pkgs.stdenv.isLinux {
      enable = true;
      extraArgs = "--keep-since 7d --keep 3";
    };
  };
}
