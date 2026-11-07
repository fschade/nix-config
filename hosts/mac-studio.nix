{
  pkgs,
  vars,
  ...
}: let
  hostname = "mac-studio";
in {
  imports = [
    ../modules/darwin
  ];

  networking.hostName = hostname;
  networking.computerName = hostname;
  system.defaults.smb.NetBIOSName = hostname;

  home-manager.users.${vars.user.name} = {
    imports = [
      ../home/os/darwin.nix
      ../home/cli/claude
      ../home/cli/core
      ../home/cli/dev.nix
      ../home/cli/ops.nix
      ../home/gui/ghostty.nix
      ../home/gui/raycast.nix
      ../home/gui/aerospace
      ../home/gui/karabiner
      ../home/gui/sketchybar
      ../home/gui/wallpaper.nix
    ];
    home.packages = [pkgs.vikunja-desktop pkgs.vja];
  };

  homebrew = {
    casks = [
      "fujitsu-scansnap-home"
      "whatsapp"
      "home-assistant"
      "obs" # streaming, only this host has the cams and the rode gear

      "claude"
    ];

    masApps = {
      "MoneyMoney" = 872698314;
    };
  };

  local.loginItems = [
    "/Users/${vars.user.name}/Applications/Home Manager Apps/Vikunja Desktop.app"
    "/Applications/Home Assistant.app"
    "/Applications/OBSBOT_Center.app" # no cask, install by hand (MANUAL.md)
  ];

  local.webApps = [
    "dashboard"
    "opentalk"
  ];
}
