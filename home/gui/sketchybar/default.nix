{...}: {
  programs.sketchybar = {
    enable = true;
    service.enable = true; # launchd agent, start sketchybar at login
    configType = "bash";
    config = {
      source = ./config;
      recursive = true;
    };
  };
}
