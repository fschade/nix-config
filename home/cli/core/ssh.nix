{...}: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    # agent forwarding only for the homelab boxes: root on any host you forward
    # to can use every loaded key, so a global "yes" hands the agent to one-off
    # and untrusted hosts too. `ssh -A` still works for the odd case.
    settings."pve-*".ForwardAgent = "yes";

    settings."*" = {
      # no explicit IdentityFile, let ssh offer its default keys in order
      # (modern id_ed25519 before the old id_rsa).
      # UseKeychain is macOS only.
      IgnoreUnknown = "UseKeychain";
      UseKeychain = "yes"; # macOS keychain
    };
  };
}
