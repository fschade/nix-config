{...}: {
  # minimal status bar: aerospace workspace indicator (1-9, active highlighted) + focused app.
  # aerospace hides the macos spaces so this shows where you are.
  programs.sketchybar = {
    enable = true;
    service.enable = true; # launchd agent, start sketchybar at login
    configType = "bash";
    config = {
      source = ./config;
      recursive = true;
    };
    # includeSystemPath is on by default and suffixes /opt/homebrew/bin onto the
    # wrapper, so the daemon and the scripts it forks find the brew aerospace cli
  };
}
