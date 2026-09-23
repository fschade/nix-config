{
  config,
  lib,
  ...
}: {
  xdg.configFile."aerospace/aerospace.toml".text =
    builtins.replaceStrings
    ["@sketchybar@"]
    [(lib.getExe config.programs.sketchybar.finalPackage)]
    (builtins.readFile ./aerospace.toml);
}
