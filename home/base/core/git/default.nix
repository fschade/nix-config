{
  config,
  lib,
  my,
  ...
}: {
  # `programs.git` will generate the config file: ~/.config/git/config
  # to make git use this config file, `~/.gitconfig` should not exist!
  #
  #    https://git-scm.com/docs/git-config#Documentation/git-config.txt---global
  home.activation.removeExistingGitconfig = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
    rm -f ${config.home.homeDirectory}/.gitconfig
  '';

  # GitHub CLI tool
  # https://cli.github.com/manual/
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      prompt = "enabled";
    };
  };

  xdg.configFile = {
    "git/commit-message".source = ./commit-message;
    "git/ignore".source = ./ignore;
  };

  programs.git = {
    enable = true;
    lfs.enable = true;

    settings = {
      user = {
        name = my.vars.user.fullName;
        email = my.vars.user.email;
      };

      commit.template = "${config.xdg.configHome}/git/commit-message";
      init.defaultBranch = "main";
      trim.bases = "develop,master,main"; # for git-trim
      push.autoSetupRemote = true;
      pull.rebase = true;
      log.date = "iso"; # use iso format for date
    };
  };

  # A syntax-highlighting pager for git, diff, grep, and blame output
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      diff-so-fancy = true;
      line-numbers = true;
      true-color = "always";
    };
  };

  # Git terminal UI (written in go).
  programs.lazygit.enable = true;
}
