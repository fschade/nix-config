{
  config,
  lib,
  pkgs,
  vars,
  ...
}: {
  # committed: conventional-commit linter (called by each repo's lefthook).
  # difftastic: structural (syntax-aware) diff, used on demand via `git dft`
  # (delta stays the default pager for `git diff`/`log`/`show`).
  home.packages = [pkgs.committed pkgs.difftastic];

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
      alias.dft = "!git -c diff.external=difft diff"; # structural diff on demand
      init.defaultBranch = "main";
      trim.bases = "develop,master,main"; # for git-trim
      push.autoSetupRemote = true;
      pull.rebase = true;
      log.date = "iso";

      rebase.autosquash = true; # auto-apply git-absorb `fixup!` commits on rebase
      rebase.autostash = true; # stash/pop a dirty tree around rebase (and pull)
      fetch.prune = true; # drop local refs for branches deleted on the remote
      rerere.enabled = true; # remember + reuse conflict resolutions across rebases
      merge.conflictStyle = "zdiff3"; # conflict markers that show the common base
      diff.algorithm = "histogram"; # clearer, more stable diffs than the default
      branch.sort = "-committerdate"; # list most-recently-used branches first
      column.ui = "auto"; # columnar `git branch` / `git status` output
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
