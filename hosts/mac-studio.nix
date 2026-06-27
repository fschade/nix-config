{vars, ...}: let
  hostname = "mac-studio";
in {
  imports = [
    ../modules/darwin
  ];

  networking.hostName = hostname;
  networking.computerName = hostname;
  system.defaults.smb.NetBIOSName = hostname;

  home-manager.users.${vars.user.name}.imports = [
    ../home/os/darwin.nix
    ../home/cli/core
    ../home/cli/dev.nix
    ../home/cli/ops.nix
    ../home/cli/proxy
    ../home/gui/ghostty.nix
    ../home/gui/aerospace
    ../home/gui/sketchybar
    ../home/gui/wallpaper.nix
  ];

  homebrew = {
    casks = [
      "fujitsu-scansnap-home"
      "whatsapp"
      "ticktick"

      "claude" # Claude desktop app
      "claude-code" # Claude Code CLI
    ];

    masApps = {
      "MoneyMoney" = 872698314;
    };
  };

  local.loginItems = ["/Applications/TickTick.app"];
}
