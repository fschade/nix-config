{pkgs, ...}: {
  home.packages = with pkgs; [
    # core tools
    fastfetch
    neovim # also the EDITOR, see home.nix
    helix # `hx`: modal editor, LSP and tree-sitter builtin
    gnumake # Makefile
    just # command runner like gnumake but simpler
    git # used by nix flakes
    git-lfs # used by huggingface models

    # system monitoring
    procs # modern ps
    btop

    # archives
    zip
    xz
    zstd
    unzipNLS
    p7zip

    # text processing
    # Docs: https://github.com/learnbyexample/Command-line-text-processing
    gnugrep # GNU grep, gives `grep`/`egrep`/`fgrep`
    gawk # GNU awk, pattern scanning language
    gnutar
    gnused # GNU sed, mostly for replacing text in files
    sad # search and replace like sed, but with diff preview

    jq # command-line JSON processor
    jless # TUI viewer for big JSON/YAML
    yq-go # yaml processor https://github.com/mikefarah/yq
    jc # converts output of many cli tools to JSON, YAML

    # file search & navigation
    fd # find files by name, faster than find
    findutils
    eza # modern ls
    (ripgrep.override {withPCRE2 = true;}) # search by content, better grep
    ripgrep-all # `rga`: ripgrep that also search PDFs, docx, sqlite, archives
    broot # `br`: fuzzy tree navigator + file launcher

    # disk usage
    duf # better df
    dust # more intuitive du, in rust
    gdu # disk usage analyzer, like du
    ncdu # disk usage interactive TUI, like du

    # networking tools
    mtr # network diagnostic (traceroute)
    gping # ping but with a graph (TUI)
    dnsutils # `dig` + `nslookup`
    ldns # like dig, gives the `drill` command
    doggo # DNS client for humans
    wget
    curl
    curlie # curl with httpie
    httpie
    aria2 # multi-protocol download tool
    socat # like openbsd-netcat
    nmap # network discovery and security auditing
    ipcalc # IPv4/v6 address calculator
    iperf3 # network performance test
    hyperfine # benchmarking tool
    tcpdump # network sniffer
    bandwhich # per-process network bandwidth (TUI)

    # file transfer
    rsync
    croc # transfer files between computers, secure and easy

    # security
    libargon2
    openssl
    sops # edit/decrypt secret files. use it with the IntelliJ sops plugin
    age # file encryption backend for sops

    # nix tooling
    nix-output-monitor # `nom`: nix build with richer logs
    nix-tree # TUI derivation dependency graph

    # docs / help. `cht.sh <cmd>` is a docs wiki for any tool, online, broader
    # than tldr. also questions: `cht.sh tar "extract gz"`. tldr (offline) is
    # in cli.nix via programs.tealdeer.
    cht-sh

    # misc
    file
    which
    tree
  ];
}
