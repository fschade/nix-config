{
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
      process-compose # run multiple local processes together (backend + web + …), TUI
      alejandra # nix formatter (also used by `mise run fmt` / `nix fmt`)
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

      # nix authoring helpers
      nix-init # generate a nix derivation from a url
      nix-melt # TUI flake.lock viewer
      deadnix # find dead nix code (used by `mise run lint`)
      statix # nix linter (used by `mise run lint`)

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
    # macOS container runtime: colima (real dockerd in a Lima VM) replaces Docker
    # Desktop — free/OSS for any use. docker-client + compose are the CLIs.
    ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
      colima
      docker-client
      docker-compose
    ];

  xdg.configFile = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    "docker/cli-plugins/docker-compose".source = "${pkgs.docker-compose}/bin/docker-compose";

    # colima resource defaults for *new* instances (content + rationale live in
    # the yaml). Recreate the VM to pick up changes: `colima delete && colima start`.
    "colima/_templates/default.yaml".source = ../../custom/config/colima/default.yaml;
  };

  # supply chain: pnpm waits 7 days (value in minutes) before installing a new
  # release, so freshly compromised packages never reach us. the global rc
  # covers every project pnpm; plain npm has no such setting.
  # idea via trailofbits/claude-code-config, thanks.
  home.file."Library/Preferences/pnpm/rc" = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    text = "minimum-release-age=10080\n";
  };

  # Copier templates at a stable HOME path (symlink to the store copy), so the
  # `copier copy` command is the same no matter where this repo lives:
  #   copier copy ~/.local/share/copier/templates/go-service ./my-project
  xdg.dataFile."copier/templates".source = ../../custom/templates/copier;

  # Docker runtime switcher (Colima <-> OrbStack). Script lives as a real file
  # under custom/scripts/ (per repo policy: longer scripts aren't inlined in nix);
  # sourced into zsh so `docker-use-colima` / `docker-use-orb` / `docker-use-status`
  # become shell commands. Darwin-only (both runtimes are macOS).
  programs.zsh.initContent = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
    lib.mkAfter (builtins.readFile ../../custom/scripts/darwin/docker-use.zsh)
  );

  # Workstation-only shortcuts (for the tools above).
  home.shellAliases = {
    lg = "lazygit";
    lzd = "lazydocker";
  };
}
