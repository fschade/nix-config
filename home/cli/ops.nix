{pkgs, ...}: {
  home.packages = with pkgs; [
    kubectl
    k9s # kubernetes TUI
    kubectx # kubectx + kubens
    stern # tail logs across many pods at once (by label/regex)
    talosctl # manage Talos nodes
  ];

  home.shellAliases = {
    k = "kubectl";
    kx = "kubectx";
    kn = "kubens";
  };
}
