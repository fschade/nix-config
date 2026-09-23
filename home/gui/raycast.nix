{...}: {
  launchd.agents.raycast = {
    enable = true;
    config = {
      ProgramArguments = ["/usr/bin/open" "-a" "Raycast"];
      RunAtLoad = true;
    };
  };
}
