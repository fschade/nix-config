{
  config,
  lib,
  vars,
  ...
}: {
  # macOS "Open at Login" items. nix-darwin has no native option for these, so
  # expose a small list option that hosts can extend (e.g. hosts/mac-studio.nix
  # adds its own), then reconcile the merged set on activation.
  options.local.loginItems = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    example = ["/Applications/Raycast.app"];
    description = "App bundle paths to open at login (System Settings > General > Login Items).";
  };

  config = {
    # Shared across every darwin host. Host-only items (e.g. TickTick) are added
    # in the host file and merge into this list.
    local.loginItems = [
      "/Applications/Thaw.app"
      "/Applications/Raycast.app"
      "/Applications/BetterDisplay.app"
      "/Applications/Amphetamine.app"
      "/Applications/JetBrains Toolbox.app"
      "/Applications/AppCleaner.app"
      "/Applications/Itsycal.app"
      "/Applications/Bitwarden.app" # password manager — handy at login
      "/Applications/macshot.app" # screenshots: must run for the global hotkey to work
      "/Applications/RODE Virtual Channels.app" # keep audio routing/mixing active
    ];

    # Reconcile as the user via System Events (same `sudo -u` pattern as
    # activateSettings in defaults.nix): clear all login items, then add exactly
    # local.loginItems — so the lists above and in the host file are the source
    # of truth. `|| true` keeps a denied automation prompt from failing the
    # switch; grant the one-time "control System Events" prompt for it to apply.
    system.activationScripts.postActivation.text = lib.mkAfter ''
      sudo -u ${vars.user.name} /usr/bin/osascript -e 'tell application "System Events" to delete every login item' >/dev/null || true
      ${lib.concatMapStringsSep "\n" (path: ''
          sudo -u ${vars.user.name} /usr/bin/osascript -e 'tell application "System Events" to make login item at end with properties {path:"${path}", hidden:false}' >/dev/null || true
        '')
        config.local.loginItems}
    '';
  };
}
