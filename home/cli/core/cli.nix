{...}: {
  programs.navi = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };
  xdg.dataFile."navi/cheats/personal".source = ./cheats;

  programs.bat = {
    enable = true;
    config.pager = "less -FR";
  };

  programs.fzf = {
    enable = true;
    historyWidget.command = "";
  };

  programs.tealdeer = {
    enable = true;
    settings = {
      display = {
        compact = false;
        use_pager = true;
      };
      updates = {
        auto_update = true;
        auto_update_interval_hours = 720; # but max every 30 days
      };
    };
  };

  programs.yazi = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    settings.mgr = {
      show_hidden = true;
      sort_dir_first = true;
    };
  };

  programs.broot = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    settings = {
      update_check = false; # nix manage the binary, skip the update nag
      style = "compact"; # tidy list, not the full screen takeover
      inline_height = 20; # cap height in inline mode (default 0 = whole screen)
      filter_mode_shell_up_key_binding = "directory";
    };
  };

  programs.herdr = {
    enable = true;
    settings = {
      onboarding = false; # skip the first-run wizard, config comes from here
      keys.prefix = "ctrl+b";
      theme.name = "catppuccin";
      update.version_check = false; # nix manage the binary, skip the update nag
    };
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    config.warn_timeout = "1m";
    stdlib =
      builtins.readFile ../../../custom/scripts/common/direnv-layout-dir.sh;
  };
}
