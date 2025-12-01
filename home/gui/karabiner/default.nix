{
  pkgs,
  lib,
  ...
}: {
  # ⌥a/⌥o/⌥u -> ä/ö/ü and ⌥n -> ~ (⌥s -> ß is native): US layout stays,
  # german chars are one chord away. the chords use the ⌥u dead key, so
  # terminals must keep option as the compose key (ghostty.nix does).
  #
  # karabiner writes into its own config file, a read-only store symlink
  # breaks it — install a writable copy, gui edits get overwritten on switch.
  home.activation = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    karabinerConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD install -Dm644 ${./karabiner.json} "$HOME/.config/karabiner/karabiner.json"
    '';
  };
}
