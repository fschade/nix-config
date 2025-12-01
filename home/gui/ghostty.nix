{...}: {
  programs.ghostty = {
    enable = true;
    # pkgs.ghostty is broken on darwin, the app comes from the brew cask —
    # this module only manages config. null also skips hm's config validation,
    # which would need a real ghostty binary.
    package = null;

    enableZshIntegration = true;
    enableBashIntegration = true;
    installBatSyntax = false;

    settings = {
      font-size = 13;

      # keep option as the macos compose key so the karabiner umlaut chords
      # (see home/gui/karabiner) also work in the terminal. ghostty would
      # default to option-as-alt on a US layout and break them. trade-off:
      # no alt-<letter> keybinds in ghostty, zellij runs via its ctrl modes.
      macos-option-as-alt = false;

      background-opacity = 0.93;
      # only on macos
      background-blur-radius = 10;
      scrollback-limit = 20000;
    };
  };
}
