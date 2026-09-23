{
  pkgs,
  lib,
  ...
}: {
  home.activation = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    karabinerConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD install -Dm644 ${./karabiner.json} "$HOME/.config/karabiner/karabiner.json"
    '';
  };
}
