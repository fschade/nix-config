{
  lib,
  pkgs,
  ...
}: {
  # cheatsheet launcher, a fzf picker over snippets. zsh rebinds it to Ctrl-/
  # (see home/cli/core/zsh.nix), bash keeps navi's own Ctrl-G. `cs` works in both.
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

  # fuzzy finder. atuin owns Ctrl-R (see below), so drop fzf's history widget.
  # otherwise both bind it and home-manager warns about the clash.
  programs.fzf = {
    enable = true;
    historyWidget.command = "";
  };

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
    enableBashIntegration = true;
    enableZshIntegration = true;
    # [mgr] since yazi 25.5.31, the old [manager] name only trips the migration
    # warning on every launch (the store-managed toml is read-only)
    settings.mgr = {
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

  # agent multiplexer, also the persistent-session layer over SSH (detach/attach
  # on the pve servers, sessions survive a server restart). shell auto-start is
  # OFF, Ghostty do the local splits. run `herdr`, or `herdr session attach
  # <name>` for a named one. every binding sits behind the Ctrl-b prefix, so
  # nothing clash with the aerospace / karabiner alt binds.
  programs.herdr = {
    enable = true;
    settings = {
      onboarding = false; # skip the first-run wizard, config comes from here
      # catppuccin/nix has no herdr module, herdr ships the palette itself
      theme.name = "catppuccin";
      update.version_check = false; # nix manage the binary, skip the update nag
    };
  };

  # per-dir env, auto-loads a project flake devShell via nix-direnv
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    stdlib =
      # moves .direnv out of the project, see the script.
      builtins.readFile ../../../custom/scripts/common/direnv-layout-dir.sh
      # `use docker orb|colima` in a .envrc sets per-dir DOCKER_CONTEXT.
      # darwin only, targets the colima/orbstack contexts.
      + lib.optionalString pkgs.stdenv.hostPlatform.isDarwin (
        builtins.readFile ../../../custom/scripts/darwin/direnv-use-docker.sh
      );
  };
}
