{
  config,
  lib,
  vars,
  ...
}: {
  home.activation.removeExistingGitconfig = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
    rm -f ${config.home.homeDirectory}/.gitconfig
  '';

  # GitHub CLI - https://cli.github.com/manual/
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
        name = vars.user.fullName;
        email = vars.user.email;
      };

      commit.template = "${config.xdg.configHome}/git/commit-message";
      init.defaultBranch = "main";
      trim.bases = "develop,master,main"; # for git-trim
      push.autoSetupRemote = true;
      pull.rebase = true;
      log.date = "iso";
    };
  };

  # syntax-highlighting pager for git diff/grep/blame
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      diff-so-fancy = true;
      line-numbers = true;
      true-color = "always";
    };
  };

  # git terminal UI
  programs.lazygit.enable = true;
}
