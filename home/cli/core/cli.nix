{
  lib,
  pkgs,
  ...
}: {
  # cheatsheet launcher, Ctrl-G open a fzf picker over snippets.
  # personal cheats are below, add more with `navi repo add denisidoro/cheats`.
  programs.navi = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };
  # my cheats, versioned. go to ~/.local/share/navi/cheats/personal
  xdg.dataFile."navi/cheats/personal".source = ./cheats;

  # cat clone with syntax highlight and git
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
        # refresh page cache by itself, no manual `tldr --update`. works on macOS too.
        auto_update = true;
        auto_update_interval_hours = 720; # but max every 30 days
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

  # smarter cd, remembers your most used dirs. `z foo`, `zi` for fzf
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  # shell history in a SQLite db, optional encrypted sync across machines
  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    # only the values that differ from atuin defaults.
    settings = {
      update_check = false; # nix manage the binary, skip the update nag
      style = "compact"; # tidy list, not the full screen takeover
      inline_height = 20; # cap height in inline mode (default 0 = whole screen)
      # up shows commands run before in this dir. Ctrl-R still search all.
      # empty in a dir you never used, thats fine.
      filter_mode_shell_up_key_binding = "directory";
    };
  };

  # terminal multiplexer, mostly for persistent sessions over SSH (detach/attach
  # on the pve servers). shell auto-start is OFF, Ghostty do local splits.
  # run `zellij` / `zellij attach` when you want it. catppuccin themes it by itself.
  programs.zellij = {
    enable = true;
    settings = {
      mouse_mode = true; # click panes / scroll (default off), Shift+drag = native select
      session_serialization = true; # sessions survive reboots, not only disconnects
    };
    # aerospace grabs alt-h/j/k/l/=/-, karabiner grabs alt-n/o (umlauts) —
    # these zellij defaults can never fire, unbind them so the config dont lie.
    # the other alt binds dont reach zellij from ghostty either (option is the
    # compose key there), so day to day zellij runs on its ctrl modes:
    # Ctrl p -> n = new pane, Ctrl t -> n = new tab.
    extraConfig = ''
      keybinds {
          unbind "Alt h" "Alt j" "Alt k" "Alt l" "Alt =" "Alt -" "Alt n" "Alt o"
      }
    '';
  };

  # per-dir env, auto-loads a project flake devShell via nix-direnv
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    # `use docker orb|colima` in a .envrc sets per-dir DOCKER_CONTEXT.
    # darwin only, targets the colima/orbstack contexts.
    stdlib = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
      builtins.readFile ../../../custom/scripts/darwin/direnv-use-docker.sh
    );
  };
}
