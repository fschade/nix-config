{...}: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings."*" = {
      ForwardAgent = "yes";
      # no explicit IdentityFile, let ssh offer its default keys in order
      # (modern id_ed25519 before the old id_rsa).
      # UseKeychain is macOS only.
      IgnoreUnknown = "UseKeychain";
      UseKeychain = "yes"; # macOS keychain
    };
  };
}
