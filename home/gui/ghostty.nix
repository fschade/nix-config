{...}: {
  programs.ghostty = {
    enable = true;
    # pkgs.ghostty is broken on darwin, the app comes from the brew cask.
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
      # no alt-<letter> keybinds in ghostty, herdr runs on its Ctrl-b prefix.
      macos-option-as-alt = false;

      background-opacity = 0.93;
      # background-blur-radius is the old name, ghostty resolves it to
      # background-blur and drops the alias silently one day, so use the new key.
      background-blur = 10;
    };
  };
}
