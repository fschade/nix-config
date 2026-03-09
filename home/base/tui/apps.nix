{pkgs, ...}: {
  home.packages = with pkgs; [
    # DEV ###############################################################
    lazydocker # Docker terminal UI.
    tokei # count lines of code, alternative to cloc
    alejandra
    buildifier # bazel tools, used to check starlark

    # db related
    sqlite

    # misc
    devbox
    bfg-repo-cleaner # remove large files from git history
    k6 # load testing tool

    # solve coding exercises - learn by doing
    exercism

    # Automatically trims your branches whose tracking remote refs are merged or gone
    # It's really useful when you work on a project for a long time.
    git-trim
    gitleaks
  ];
}
