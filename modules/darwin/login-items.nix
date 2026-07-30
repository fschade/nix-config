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

    # clears every login item, then adds exactly local.loginItems, so nix stays the
    # truth. script and the automation grant it needs:
    # custom/scripts/darwin/login-items.sh and MANUAL.md.
    system.activationScripts.postActivation.text = lib.mkAfter ''
      ${pkgs.bash}/bin/bash ${../../custom/scripts/darwin/login-items.sh} "${vars.user.name}" ${lib.escapeShellArgs config.local.loginItems}
    '';

    # the list again as a file, so scripts/deploy.sh can reconcile once more after
    # it builds the web-apps. a web-app that is also a login item (Pushover) does
    # not exist yet when the switch runs this, the build comes later. mirrors how
    # web-apps.nix hands its list to the builder.
    environment.etc."login-items".text =
      lib.concatStringsSep "\n" config.local.loginItems;
  };
}
