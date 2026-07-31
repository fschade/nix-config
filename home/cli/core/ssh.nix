{...}: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    # agent forwarding only for the homelab boxes: root on any host you forward
    # to can use every loaded key, so a global "yes" hands the agent to one-off
    # and untrusted hosts too. `ssh -A` still works for the odd case.
    settings."pve-*".ForwardAgent = "yes";

    settings."*" = {
      # uses id_rsa by default
      # UseKeychain is macOS only.
      IgnoreUnknown = "UseKeychain";
      UseKeychain = "yes"; # macOS keychain
    };
  };
}
