{...}: {
  programs.bash = {
    enable = true;
    enableCompletion = true;
    historyControl = ["ignoredups" "ignorespace"];
  };

  # aliases for bash + zsh, on every machine.
  # eza is in core, icons need the terminal nerd font.
  home.shellAliases = {
    ls = "eza --group-directories-first --icons";
    ll = "eza -l --group-directories-first --icons --git";
    la = "eza -la --group-directories-first --icons --git";
    lt = "eza --tree --level=2 --icons";
    ".." = "cd ..";
    "..." = "cd ../..";
    cs = "navi"; # cheatsheet, open navi snippet picker
    docs = "cht.sh"; # docs/wiki for any command: `docs eza`, `docs tar extract`
    watch = "viddy"; # macOS has no `watch`, viddy is the modern drop-in
  };
}
