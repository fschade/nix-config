{pkgs, ...}: {
  # interactive cheatsheet/snippet launcher — Ctrl-G opens an fzf picker over
  # snippets (placeholders like <container> are prompted). Personal cheats are
  # vendored below; add community collections with `navi repo add denisidoro/cheats`.
  programs.navi = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };
  # version-controlled personal cheats (-> ~/.local/share/navi/cheats/personal)
  xdg.dataFile."navi/cheats/personal".source = ./cheats;

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
    settings = {
      display = {
        compact = false;
        use_pager = true;
      };
      updates = {
        # Fetch/refresh the page cache on demand — no manual `tldr --update`, and
        # works on macOS too (unlike enableAutoUpdates, which is systemd-only).
        auto_update = true;
        auto_update_interval_hours = 720; # ...but at most every 30 days
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
    # Only values that diverge from atuin's defaults.
    settings = {
      update_check = false; # nix manages the binary; skip the update nag
      style = "compact"; # tidy list instead of the full-screen takeover
      inline_height = 20; # cap height in inline mode (default 0 = whole screen)
      # ↑ shows commands previously run in the current directory (across sessions);
      # Ctrl-R still searches everything. Empty in a dir you've never worked in — expected.
      filter_mode_shell_up_key_binding = "directory";
    };
  };

  # terminal multiplexer — mainly for persistent sessions over SSH (detach/attach
  # on the pve servers). Shell auto-start is deliberately OFF (Ghostty handles
  # local splits); run `zellij` / `zellij attach` when you actually want it.
  # catppuccin (autoEnable) themes it automatically — no manual theme needed.
  programs.zellij = {
    enable = true;
    settings = {
      mouse_mode = true; # click panes / scroll (default off); Shift+drag = native select
      session_serialization = true; # sessions survive reboots, not just disconnects
    };
    # aerospace still owns alt-h/j/k/l (window focus) and alt-=/- (resize), so only
    # those zellij Alt defaults are dead — unbind just them. Everything else
    # (Alt n new-pane, Alt f floating, Alt [ / ] layouts, …) works again now that
    # the A–Z workspaces were dropped from aerospace.
    extraConfig = ''
      keybinds {
          unbind "Alt h" "Alt j" "Alt k" "Alt l" "Alt =" "Alt -"
      }
    '';
  };

  # per-directory env, and auto-loads a project's flake devShell (via nix-direnv)
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };
}
