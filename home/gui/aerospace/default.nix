{
  config,
  lib,
  ...
}: {
  # aerospace exec commands dont see the nix profile on PATH, so the toml
  # carries a @sketchybar@ placeholder and gets the store path substituted here
  #
  # needs home/gui/sketchybar imported on the same host, finalPackage only
  # exists when that module is enabled
  xdg.configFile."aerospace/aerospace.toml".text =
    builtins.replaceStrings
    ["@sketchybar@"]
    [(lib.getExe config.programs.sketchybar.finalPackage)]
    (builtins.readFile ./aerospace.toml);
}
