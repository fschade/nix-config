{
  config,
  lib,
  pkgs,
  vars,
  ...
}: {
  options.local.loginItems = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    example = ["/Applications/Raycast.app"];
    description = "App bundle paths to open at login (System Settings > General > Login Items).";
  };

  config = {
    local.loginItems = [
      "/Applications/AltTab.app" # its hotkey only works while it runs
      "/Applications/BetterDisplay.app"
      "/Applications/Amphetamine.app"
      "/Applications/JetBrains Toolbox.app"
      "/Applications/AppCleaner.app"
      "/Applications/Itsycal.app"
      "/Applications/Bitwarden.app"
      "/Applications/macshot.app" # its hotkey only works while it runs
      "/Applications/RODE Virtual Channels.app"
    ];

    system.activationScripts.postActivation.text = lib.mkAfter ''
      ${pkgs.bash}/bin/bash ${../../custom/scripts/darwin/login-items.sh} "${vars.user.name}" ${lib.escapeShellArgs config.local.loginItems}
    '';
  };
}
