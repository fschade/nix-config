{pkgs, ...}: {
  home.packages = with pkgs; [
    fastfetch
    neovim # also the EDITOR, see home.nix
    helix # `hx`: modal editor, LSP and tree-sitter builtin
    gnumake # Makefile
    just # command runner like gnumake but simpler
    git-lfs # used by huggingface models

    procs # modern ps
    btop
    witr # "why is this running": trace a process/port/container to its cause
    usbtree # usb device tree with link speed (TUI)

    zip
    xz
    zstd
    unzipNLS
    p7zip

    gnugrep # GNU grep, gives `grep`/`egrep`/`fgrep`
    gawk # GNU awk, pattern scanning language
    gnutar
    gnused # GNU sed, mostly for replacing text in files
    sad # search and replace like sed, but with diff preview

    jq # command-line JSON processor
    jless # TUI viewer for big JSON/YAML
    yq-go # yaml processor https://github.com/mikefarah/yq
    jc # converts output of many cli tools to JSON, YAML

    fd # find files by name, faster than find
    findutils
    eza # modern ls
    (ripgrep.override {withPCRE2 = true;}) # search by content, better grep
    ripgrep-all # `rga`: ripgrep that also search PDFs, docx, sqlite, archives

    duf # better df
    dust # more intuitive du, in rust
    gdu # disk usage analyzer, like du
    ncdu # disk usage interactive TUI, like du

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

    rsync
    croc # transfer files between computers, secure and easy

    libargon2
    openssl
    sops # edit/decrypt secret files. use it with the IntelliJ sops plugin
    age # file encryption backend for sops
    bitwarden-cli # `bw`: vault access from the shell, also what the raycast extension talks to

    nix-output-monitor # `nom`: nix build with richer logs
    nix-tree # TUI derivation dependency graph

    cht-sh

    file
    which
    tree
  ];
}
