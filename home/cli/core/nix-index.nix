{inputs, ...}: {
  imports = [inputs.nix-index-database.homeModules.nix-index];

  # prebuilt db that refreshes itself (no manual `nix-index` runs), plus the
  # command-not-found / nix-locate integration that uses it.
  programs.nix-index.enable = true;

  # `comma`: run any program without installing it (`, foo`), uses the db.
  programs.nix-index-database.comma.enable = true;
}
