{pkgs, ...}: {
  # minimal status bar: aerospace workspace indicator (1-9, active highlighted) + focused app.
  # aerospace hides the macos spaces so this show where you are.
  programs.sketchybar = {
    enable = true;
    service.enable = true; # launchd agent, start sketchybar at login
    configType = "bash";
    config = {
      source = ./config;
      recursive = true;
    };
    extraPackages = [pkgs.jq];
    # includeSystemPath is on by default. sketchybarrc also prepend /opt/homebrew/bin so plugins find the `aerospace` cli.
  };
}
