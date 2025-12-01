_: let
  hostname = "mac-studio";
in {
  networking.hostName = hostname;
  networking.computerName = hostname;
  system.defaults.smb.NetBIOSName = hostname;

  homebrew = {
    casks = [
      "dotnet-sdk6-0-400"
      "fujitsu-scansnap-home"
      "whatsapp"
      "ticktick"
    ];

    masApps = {
      "MoneyMoney" = 872698314;
    };

    taps = [
      "isen-ng/homebrew-dotnet-sdk-versions"
    ];
  };
}
