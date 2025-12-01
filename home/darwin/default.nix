{my, ...}: {
  imports =
    (my.lib.scanPaths ./.)
    ++ [
      ../base/core
      ../base/tui
      ../base/gui
      ../base/home.nix
    ];

  home.homeDirectory = "/Users/${my.vars.user.name}";

  # enable management of XDG base directories on macOS.
  xdg.enable = true;
}
