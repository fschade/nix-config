{lib, ...}: {
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # Make zsh's line editor handle the keys a dev expects in any xterm-style
    # terminal (Ghostty, iTerm, Terminal.app, most Linux terminals). Notably
    # fixes forward-Delete inserting a stray "~": it sends \e[3~, which zsh
    # didn't bind, so the trailing ~ leaked as a literal character.
    initContent = lib.mkMerge [
      ''
        bindkey "^[[3~"   delete-char        # Delete (forward) — fixes the stray ~
        bindkey "^[[H"    beginning-of-line  # Home
        bindkey "^[[F"    end-of-line        # End
        bindkey "^[[1;5C" forward-word       # Ctrl+Right  → next word
        bindkey "^[[1;5D" backward-word      # Ctrl+Left   → prev word
        bindkey "^[[1;3C" forward-word       # Alt+Right   → next word
        bindkey "^[[1;3D" backward-word      # Alt+Left    → prev word
        bindkey "^[[3;5~" kill-word          # Ctrl+Delete → delete next word
        bindkey "^[^?"    backward-kill-word # Alt+Backspace → delete prev word
      ''
      # Must run AFTER the navi/atuin integrations (default order) define their
      # widgets/bindings, hence mkAfter.
      (lib.mkAfter ''
        # navi's snippet picker on Ctrl-/ (sends ^_); works inside zellij too,
        # unlike Ctrl-G. Also reachable via the `cs` alias.
        bindkey -r "^g"            # drop navi's default Ctrl-G binding
        bindkey "^_" _navi_widget  # Ctrl-/
        # `?` types a literal character (disable atuin's `?`-at-empty-prompt AI).
        bindkey "?" self-insert
      '')
    ];

    # (Ctrl-R / up-history is handled by atuin; this is the local fallback.)
    history = {
      size = 50000;
      save = 50000;
      ignoreDups = true;
      ignoreSpace = true;
      expireDuplicatesFirst = true;
      share = true;
    };
  };
}
