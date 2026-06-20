{...}: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings."*" = {
      ForwardAgent = "yes";
      # No explicit IdentityFile: let ssh offer its default keys in preference
      # order (modern id_ed25519 before the legacy id_rsa).
      # UseKeychain is macOS only.
      IgnoreUnknown = "UseKeychain";
      UseKeychain = "yes"; # macOS keychain
    };
  };
}
