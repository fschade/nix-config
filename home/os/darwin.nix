{
  lib,
  vars,
  ...
}: {
  # mkDefault so the nix-darwin hm integration (which sets the username from
  # the users attr) wins there; standalone home-manager needs it spelled out.
  home.username = lib.mkDefault vars.user.name;
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
