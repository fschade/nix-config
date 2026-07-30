{pkgs, ...}: {
  config.fonts.packages = with pkgs; [
    # icon fonts
    material-design-icons
    font-awesome
    sketchybar-app-font # app-icon glyphs for sketchybar front-app item

    # nerdfonts
    # attr names live in pkgs/data/fonts/nerd-fonts/manifests/fonts.json
    nerd-fonts.symbols-only
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.iosevka
  ];
}
