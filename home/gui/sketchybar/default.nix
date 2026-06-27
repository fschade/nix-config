{pkgs, ...}: {
  # Minimal status bar: an aerospace workspace indicator (1–9, active highlighted)
  # + the focused app. aerospace hides the macOS Spaces, so this shows where you are.
  programs.sketchybar = {
    enable = true;
    service.enable = true; # launchd agent — starts sketchybar at login
    configType = "bash";
    config = {
      source = ./config;
      recursive = true;
    };
    extraPackages = [pkgs.jq];
    # includeSystemPath is on by default; sketchybarrc also prepends
    # /opt/homebrew/bin so plugins/click-scripts find the `aerospace` CLI.
  };
}
