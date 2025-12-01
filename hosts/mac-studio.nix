{vars, ...}: let
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
      ../home/cli/proxy
      ../home/gui/ghostty.nix
      ../home/gui/aerospace
      ../home/gui/karabiner
      ../home/gui/sketchybar
      ../home/gui/wallpaper.nix
    ];
  };

  homebrew = {
    casks = [
      "fujitsu-scansnap-home"
      "whatsapp"
      "ticktick"

      "claude" # claude desktop app
      "claude-code" # claude code cli
    ];

    masApps = {
      "MoneyMoney" = 872698314;
    };
  };

  # obsbot install is manual (no cask), see MANUAL.md. login item autostarts it.
  local.loginItems = [
    "/Applications/TickTick.app"
    "/Applications/OBSBOT_Center.app"
  ];
}
