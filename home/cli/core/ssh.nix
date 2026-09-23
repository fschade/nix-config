{...}: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings."pve-*".ForwardAgent = "yes";

    settings."*" = {
      IgnoreUnknown = "UseKeychain";
      UseKeychain = "yes"; # macOS keychain
    };
  };
}
