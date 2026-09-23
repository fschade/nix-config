{pkgs, ...}: {
  config.fonts.packages = with pkgs; [
    material-design-icons
    font-awesome
    sketchybar-app-font # app-icon glyphs for sketchybar front-app item

    nerd-fonts.symbols-only
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.iosevka
  ];
}
