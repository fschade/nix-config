{inputs, ...}: {
  # https://github.com/catppuccin/nix - themes the CLI tools (bat, starship, ...)
  imports = [
    inputs.catppuccin.homeModules.catppuccin
  ];

  catppuccin = {
    enable = true; # global toggle for all catppuccin theming
    autoEnable = true; # enroll every supported program
    flavor = "mocha"; # latte | frappe | macchiato | mocha
    accent = "pink";
  };
}
