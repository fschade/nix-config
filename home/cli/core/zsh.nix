{lib, ...}: {
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # make zsh line editor handle the keys you expect in any xterm terminal
    # (Ghostty, iTerm, Terminal.app, most linux terminals). mainly fixes
    # forward-Delete inserting a stray "~": it sends \e[3~ which zsh didnt
    # bind, so the trailing ~ leaked as literal char.
    initContent = lib.mkMerge [
      ''
        bindkey "^[[3~"   delete-char        # Delete (forward), fixes the stray ~
        bindkey "^[[H"    beginning-of-line  # Home
        bindkey "^[[F"    end-of-line        # End
        bindkey "^[[1;5C" forward-word       # Ctrl+Right, next word
        bindkey "^[[1;5D" backward-word      # Ctrl+Left, prev word
        bindkey "^[[1;3C" forward-word       # Alt+Right, next word
        bindkey "^[[1;3D" backward-word      # Alt+Left, prev word
        bindkey "^[[3;5~" kill-word          # Ctrl+Delete, delete next word
        bindkey "^[^?"    backward-kill-word # Alt+Backspace, delete prev word
      ''
      # must run AFTER navi/atuin integrations define their widgets, so mkAfter.
      (lib.mkAfter ''
        # navi snippet picker on Ctrl-/ (sends ^_), works in zellij too,
        # unlike Ctrl-G. also via the `cs` alias.
        bindkey -r "^g"            # drop navi default Ctrl-G binding
        bindkey "^_" _navi_widget  # Ctrl-/
        # `?` types a literal char, disable atuin `?`-at-empty-prompt AI.
        bindkey "?" self-insert
      '')
    ];

    # Ctrl-R / up-history is done by atuin, this is the local fallback.
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
