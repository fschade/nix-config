{pkgs, ...}: {
  home.packages = with pkgs; [
    kubectl
    k9s # kubernetes tui
    kubectx # kubectx + kubens
    stern # tail logs across many pods at once (by label/regex)
    talosctl # manage talos nodes
  ];

  home.shellAliases = {
    k = "kubectl";
    kx = "kubectx";
    kn = "kubens";
  };
}
