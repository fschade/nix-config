{pkgs, ...}: {
  # cat clone with syntax highlighting and git integration
  programs.bat = {
    enable = true;
    config.pager = "less -FR";
  };

  # fuzzy finder
  programs.fzf.enable = true;

  # fast tldr client
  programs.tealdeer = {
    enable = true;
    enableAutoUpdates = true;
    settings = {
      display = {
        compact = false;
        use_pager = true;
      };
      updates = {
        auto_update = false;
        auto_update_interval_hours = 720;
      };
    };
  };

  # terminal file manager
  programs.yazi = {
    enable = true;
    package = pkgs.yazi;
    enableBashIntegration = true;
    enableZshIntegration = true;
    settings.manager = {
      show_hidden = true;
      sort_dir_first = true;
    };
  };

  # smarter cd that remembers your most-used directories (`z foo`, `zi` for fzf)
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  # shell history in a SQLite db, with optional encrypted sync across machines
  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  # per-directory env, and auto-loads a project's flake devShell (via nix-direnv)
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };
}
