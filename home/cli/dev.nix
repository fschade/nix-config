{pkgs, ...}: {
  home.packages = with pkgs; [
    # dev CLIs
    lazydocker # docker terminal UI
    dive # explore docker image layers & size
    tokei # count lines of code
    alejandra # nix formatter (also used by `mise run fmt` / `nix fmt`)
    buildifier # bazel/starlark formatter
    sqlite
    bfg-repo-cleaner # remove large files from git history
    k6 # load testing
    exercism # coding exercises
    git-trim # prune merged/gone tracking branches
    git-absorb # auto-fixup staged changes into the right prior commit
    gh-dash # TUI dashboard for GitHub PRs/issues
    gitleaks # scan for secrets (any repo)
    lefthook # git hooks manager (any repo)

    # nix authoring helpers
    nix-init # generate a nix derivation from a url
    nix-melt # TUI flake.lock viewer
    deadnix # find dead nix code (used by `mise run lint`)
    statix # nix linter (used by `mise run lint`)

    # network / debugging
    mitmproxy # http/https proxy
    wireshark # network analyzer

    # media
    ffmpeg-full
    viu # terminal image viewer
    imagemagick
    graphviz

    # misc
    caddy # webserver with automatic HTTPS
    cowsay
  ];

  # Workstation-only shortcuts (for the tools above).
  home.shellAliases = {
    lg = "lazygit";
    lzd = "lazydocker";
  };
}
