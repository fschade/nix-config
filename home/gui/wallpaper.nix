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
  # image at a standard os-agnostic place (symlink to nix store, not the repo)
  home.file."Pictures/Wallpapers/${wallpaper.file}".source = wallpaper.source;

  # apply it. macos uses desktoppr after the file is linked (writeBoundary). a future linux
  # desktop add its own setter here (swaybg/gsettings), image above is shared.
  # `|| true` keeps a headless/ssh switch (no gui session) from failing.
  home.activation.setWallpaper = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
    lib.hm.dag.entryAfter ["writeBoundary"] ''
      ${pkgs.bash}/bin/bash ${../../custom/scripts/darwin/set-wallpaper.sh} ${pkgs.desktoppr}/bin/desktoppr "${path}" ${wallpaper.color} ${wallpaper.scale}
    ''
  );
}
