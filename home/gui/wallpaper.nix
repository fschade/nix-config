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
  # Image at a standard, OS-agnostic location (symlink → nix store, not the repo).
  home.file."Pictures/Wallpapers/${wallpaper.file}".source = wallpaper.source;

  # Apply it. macOS → desktoppr, after the file is linked (writeBoundary). A future
  # Linux desktop adds its own setter here (swaybg/gsettings/…) — the image above
  # is shared. `|| true` keeps a headless/SSH switch (no GUI session) from failing.
  home.activation.setWallpaper = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
    lib.hm.dag.entryAfter ["writeBoundary"] ''
      ${pkgs.desktoppr}/bin/desktoppr all "${path}" || true
      sleep 1
      ${pkgs.desktoppr}/bin/desktoppr color ${wallpaper.color} || true
      sleep 1
      ${pkgs.desktoppr}/bin/desktoppr scale ${wallpaper.scale} || true
    ''
  );
}
