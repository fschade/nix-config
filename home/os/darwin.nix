{vars, ...}: {
  home.homeDirectory = "/Users/${vars.user.name}";

  # raycast autostart. raycast self-registers a login item too, but that api is
  # flaky, so we drive it here with launchd. `open -a` start it at login, no-op
  # if its already running.
  launchd.agents.raycast = {
    enable = true;
    config = {
      ProgramArguments = ["/usr/bin/open" "-a" "Raycast"];
      RunAtLoad = true;
    };
  };
}
