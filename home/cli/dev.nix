{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: {
  home.packages = with pkgs;
    [
      lazydocker # docker terminal UI
      dive # explore docker image layers & size
      tokei # count lines of code
      watchexec # re-run a command when files change (e.g. `watchexec -e go go test`)
      viddy # modern `watch`: re-run a cmd on an interval, highlighting what changed
      process-compose # run multiple local processes together (backend + web + ...), TUI
      alejandra # nix formatter (what `mise run fmt` runs; the flake has no `nix fmt`)
      buildifier # bazel/starlark formatter
      sqlite
      uv # fast Python package/project manager (pip + venv + lockfile), complements mise
      git-filter-repo # rewrite git history (git's recommended tool over BFG)
      k6 # load testing
      exercism # coding exercises
      git-trim # prune merged/gone tracking branches
      git-absorb # auto-fixup staged changes into the right prior commit
      worktrunk # `wt`: worktrees by branch name (switch -c, list, remove, local merge)
      gh-dash # TUI dashboard for GitHub PRs/issues
      gitleaks # scan for secrets (any repo)
      lefthook # git hooks manager (any repo)
      shellcheck # shell linter (used by `mise run check`; the devShell has it too)

      nix-init # generate a nix derivation from a url
      nix-melt # TUI flake.lock viewer
      deadnix # find dead nix code (used by `mise run check`)
      statix # nix linter (used by `mise run check`)

      mitmproxy # http/https proxy
      wireshark # network analyzer

      ffmpeg
      viu # terminal image viewer
      imagemagick
      graphviz

      caddy # webserver with automatic HTTPS
      cowsay
      gum # styled shell UIs (prompts, spinners, status) for custom/scripts/*

      inputs.localias.packages.${pkgs.stdenv.hostPlatform.system}.default

      copier
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
      docker-client
      docker-compose
    ];

  xdg.configFile = lib.mkMerge [
    {
      "copier/settings.yml".text = ''
        trust:
          - ${config.xdg.dataHome}/copier/templates/
      '';
    }
    (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      "pnpm/config.yaml".text = "minimumReleaseAge: 10080\n";
    })
  ];

  # pnpm 12 locks its store in $XDG_RUNTIME_DIR (if 0700), else in /tmp/pnpm-store-operation-locks-<uid>,
  # which the claude sandbox can't write. macos has no runtime dir, one in the cache is sandbox-writable
  home.sessionVariables = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    XDG_RUNTIME_DIR = "${config.xdg.cacheHome}/run";
  };
  home.activation.xdgRuntimeDir = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
    lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD install -d -m700 "${config.xdg.cacheHome}/run"
    ''
  );

  xdg.dataFile."copier/templates".source = ../../custom/templates/copier;

  programs.git.settings.trim.bases = "develop,master,main";

  # generated at build time instead of `wt config shell install` rewriting .zshrc. lets `wt switch` cd
  programs.zsh.initContent = let
    wtInit = pkgs.runCommand "wt-init.zsh" {} ''
      HOME=$TMPDIR ${lib.getExe' pkgs.worktrunk "wt"} config shell init zsh >$out
    '';
  in ''
    source ${wtInit}
  '';

  home.shellAliases = {
    lzd = "lazydocker";
    watch = "viddy"; # macOS has no `watch`, viddy is the modern drop-in
  };
}
