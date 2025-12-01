{
  config,
  lib,
  pkgs,
  vars,
  ...
}: {
  # macos "open at login" items. nix-darwin has no native option, so we expose
  # a small list option hosts can extend (e.g. hosts/mac-studio.nix adds its own),
  # then reconcile the merged set on activation.
  options.local.loginItems = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    example = ["/Applications/Raycast.app"];
    description = "App bundle paths to open at login (System Settings > General > Login Items).";
  };

  config = {
    # shared on every darwin host. host-only items (e.g. TickTick) get added
    # in the host file and merge into this list.
    local.loginItems = [
      "/Applications/SaneBar.app"
      # raycast autostart is a launchd agent instead (see home/os/darwin.nix),
      # the legacy login-item api is flaky and raycast self-registers anyway.
      "/Applications/AltTab.app" # ⌥Tab window switcher, must run so the hotkey work
      "/Applications/BetterDisplay.app"
      "/Applications/Amphetamine.app"
      "/Applications/JetBrains Toolbox.app"
      "/Applications/AppCleaner.app"
      "/Applications/Itsycal.app"
      "/Applications/Bitwarden.app" # password manager, handy at login
      "/Applications/macshot.app" # screenshots, must run so the global hotkey work
      "/Applications/RODE Virtual Channels.app" # keep audio routing/mixing active
    ];

    # reconcile as the user via System Events (same `sudo -u` as activateSettings
    # in defaults.nix): clear all login items, then add exactly local.loginItems,
    # so the lists here and in the host file are source of truth. `|| true` keeps
    # a denied automation prompt from failing the switch. grant the one-time
    # "control System Events" prompt so it apply.
    system.activationScripts.postActivation.text = lib.mkAfter ''
      ${pkgs.bash}/bin/bash ${../../custom/scripts/darwin/login-items.sh} "${vars.user.name}" ${lib.escapeShellArgs config.local.loginItems}
    '';
  };
}
