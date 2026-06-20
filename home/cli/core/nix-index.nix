{inputs, ...}: {
  imports = [inputs.nix-index-database.homeModules.nix-index];

  # Prebuilt, auto-refreshing database (no manual `nix-index` runs), and the
  # command-not-found / nix-locate integration that uses it.
  programs.nix-index.enable = true;

  # `comma`: run any program without installing it (`, foo`), backed by the db.
  programs.nix-index-database.comma.enable = true;
}
