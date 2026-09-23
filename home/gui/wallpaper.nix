{
  config,
  lib,
  pkgs,
  ...
}: let
  wallpapers = {
    stranger-go = {
      file = "stranger_go.jpg";
      source = ../../custom/assets/wallpaper/stranger_go.jpg;
      color = "000000";
      scale = "center";
    };
  };
  wallpaper = wallpapers.stranger-go;
  path = "${config.home.homeDirectory}/Pictures/Wallpapers/${wallpaper.file}";
in {
  home.file."Pictures/Wallpapers/${wallpaper.file}".source = wallpaper.source;

  home.activation.setWallpaper = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
    lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${../../custom/scripts/darwin/set-wallpaper.sh} ${pkgs.desktoppr}/bin/desktoppr "${path}" ${wallpaper.color} ${wallpaper.scale}
    ''
  );
}
