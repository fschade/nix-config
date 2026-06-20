{...}: {
  programs.bash = {
    enable = true;
    enableCompletion = true;
    historyControl = ["ignoredups" "ignorespace"];
  };

  # Cross-shell aliases (bash + zsh), universal — available on every machine.
  # eza is in core; icons render via the terminal's nerd font.
  home.shellAliases = {
    ls = "eza --group-directories-first --icons";
    ll = "eza -l --group-directories-first --icons --git";
    la = "eza -la --group-directories-first --icons --git";
    lt = "eza --tree --level=2 --icons";
    ".." = "cd ..";
    "..." = "cd ../..";
  };
}
