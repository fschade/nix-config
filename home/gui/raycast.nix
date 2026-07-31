{...}: {
  # raycast autostart. raycast self-registers a login item too, but that api is
  # flaky, so we drive it here with launchd. `open -a` starts it at login, no-op
  # if its already running. lives in a gui module, not the shared darwin home
  # base: the cask is mac-studio-only (modules/darwin/apps.nix), so a generic
  # darwin home from templates/darwin-default.nix must not autostart an app it
  # never got.
  launchd.agents.raycast = {
    enable = true;
    config = {
      ProgramArguments = ["/usr/bin/open" "-a" "Raycast"];
      RunAtLoad = true;
    };
  };
}
