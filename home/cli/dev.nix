{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: {
  home.packages = with pkgs;
    [
      # dev CLIs
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
      gh-dash # TUI dashboard for GitHub PRs/issues
      gitleaks # scan for secrets (any repo)
      lefthook # git hooks manager (any repo)
      shellcheck # shell linter (used by `mise run check`; the devShell has it too)

      # nix authoring helpers
      nix-init # generate a nix derivation from a url
      nix-melt # TUI flake.lock viewer
      deadnix # find dead nix code (used by `mise run check`)
      statix # nix linter (used by `mise run check`)

      # network / debugging
      mitmproxy # http/https proxy
      wireshark # network analyzer

      # media
      ffmpeg
      viu # terminal image viewer
      imagemagick
      graphviz

      # misc
      caddy # webserver with automatic HTTPS
      cowsay
      gum # styled shell UIs (prompts, spinners, status) for custom/scripts/*

      # local HTTPS dev domains with auto certs (from the localias flake input)
      inputs.localias.packages.${pkgs.stdenv.hostPlatform.system}.default

      # project scaffolding with template updates (`copier copy` / `copier update`)
      copier
    ]
    # macOS container runtime: colima is a real dockerd in a Lima VM, free/OSS
    # for any use unlike docker desktop. docker-client + compose are the CLIs.
    ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
      colima
      docker-client
      docker-compose
    ];

  xdg.configFile = lib.mkMerge [
    {
      # copier only runs a template's `_tasks` for templates you trust, and the
      # go-service one needs its task to undo the read-only store modes. listing
      # the prefix here keeps `copier copy` working as documented, the
      # alternative would be remembering `--trust` on every run.
      "copier/settings.yml".text = ''
        trust:
          - ${config.xdg.dataHome}/copier/templates/
      '';
    }
    (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      # colima defaults for *new* instances only. to pick up changes:
      # `colima delete && colima start`
      "colima/_templates/default.yaml".source = ../../custom/config/colima/default.yaml;

      # supply chain: pnpm waits 7 days (value in minutes) before installing a new
      # release, so freshly compromised packages never reach us. the global config
      # covers every project pnpm.
      # pnpm 11 dropped the npmrc-style global file, `pnpm config get globalconfig`
      # prints the yaml path it reads today.
      # idea via trailofbits/claude-code-config, thanks.
      "pnpm/config.yaml".text = "minimumReleaseAge: 10080\n";
    })
  ];

  # templates at a stable HOME path, so the command dont depend on where this
  # repo lives: `copier copy ~/.local/share/copier/templates/go-service ./my-project`
  xdg.dataFile."copier/templates".source = ../../custom/templates/copier;

  # sourced into zsh, gives `docker-use-colima` / `docker-use-orb` /
  # `docker-use-status`. darwin only, both runtimes are macOS.
  programs.zsh.initContent = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
    lib.mkAfter (builtins.readFile ../../custom/scripts/darwin/docker-use.zsh)
  );

  # git-trim (package above) needs to know the long-lived branches
  programs.git.settings.trim.bases = "develop,master,main";

  home.shellAliases = {
    lzd = "lazydocker";
    watch = "viddy"; # macOS has no `watch`, viddy is the modern drop-in
  };
}
