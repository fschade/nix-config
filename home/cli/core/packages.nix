{pkgs, ...}: {
  home.packages = with pkgs; [
    # core tools
    fastfetch
    neovim # also the EDITOR (see home.nix); Nano is shipped by default too
    gnumake # Makefile
    just # a command runner like gnumake, but simpler
    git # used by nix flakes
    git-lfs # used by huggingface models

    # system monitoring
    procs # a modern ps
    btop

    # archives
    zip
    xz
    zstd
    unzipNLS
    p7zip

    # text processing
    # Docs: https://github.com/learnbyexample/Command-line-text-processing
    gnugrep # GNU grep, provides `grep`/`egrep`/`fgrep`
    gawk # GNU awk, a pattern scanning and processing language
    gnutar
    gnused # GNU sed, very powerful (mainly for replacing text in files)
    sad # CLI search and replace, just like sed, but with diff preview

    jq # a lightweight and flexible command-line JSON processor
    jless # interactive TUI viewer for browsing large JSON/YAML
    yq-go # yaml processor https://github.com/mikefarah/yq
    jc # converts the output of popular cli tools & file-types to JSON, YAML

    # file search & navigation
    fd # search for files by name, faster than find
    findutils
    eza # modern ls
    (ripgrep.override {withPCRE2 = true;}) # search by content, replacement of grep

    # disk usage
    duf # Disk Usage/Free Utility - a better 'df' alternative
    dust # a more intuitive version of `du` in rust
    gdu # disk usage analyzer (replacement of `du`)
    ncdu # analyze your disk usage interactively, via TUI (replacement of `du`)

    # networking tools
    mtr # a network diagnostic tool (traceroute)
    gping # ping, but with a graph (TUI)
    dnsutils # `dig` + `nslookup`
    ldns # replacement of `dig`, it provides the command `drill`
    doggo # DNS client for humans
    wget
    curl
    curlie # curl with httpie
    httpie
    aria2 # a lightweight multi-protocol & multi-source command-line download utility
    socat # replacement of openbsd-netcat
    nmap # a utility for network discovery and security auditing
    ipcalc # a calculator for the IPv4/v6 addresses
    iperf3 # network performance test
    hyperfine # command-line benchmarking tool
    tcpdump # network sniffer
    bandwhich # per-process network bandwidth usage (TUI)

    # file transfer
    rsync
    croc # file transfer between computers securely and easily

    # security
    libargon2
    openssl
    sops # edit/decrypt encrypted secret files (pairs with the IntelliJ sops plugin)
    age # modern file encryption backend for sops

    # nix tooling
    nix-output-monitor # `nom`: nix build with richer logs
    nix-tree # TUI derivation dependency graph

    # docs / help — `cht.sh <cmd>` is a community docs wiki for any tool (online,
    # broader than tldr; supports questions: `cht.sh tar "extract gz"`). tldr
    # (offline, quick examples) lives in cli.nix via programs.tealdeer.
    cht-sh

    # misc
    file
    which
    tree
  ];
}
