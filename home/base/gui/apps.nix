{pkgs, ...}: {
  home.packages = with pkgs; [
    # DEV ###############################################################
    mitmproxy # http/https proxy tool
    wireshark # network analyzer

    # MEDIA #############################################################
    ffmpeg-full

    # images
    viu # Terminal image viewer with native support for iTerm and Kitty
    imagemagick
    graphviz
  ];
}
