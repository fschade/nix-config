{pkgs, ...}: {
  config.fonts.packages = with pkgs; [
    # icon fonts
    material-design-icons
    font-awesome
    sketchybar-app-font # app-icon glyphs for sketchybar front-app item

    # nerdfonts
    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable-small/pkgs/data/fonts/nerd-fonts/manifests/fonts.json
    nerd-fonts.symbols-only # symbols icon only
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.iosevka
  ];
}
