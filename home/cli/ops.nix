{pkgs, ...}: {
  home.packages = with pkgs; [
    kubectl
    k9s # kubernetes TUI
    kubectx # kubectx + kubens
    talosctl # manage Talos nodes
  ];

  home.shellAliases = {
    k = "kubectl";
    kx = "kubectx";
    kn = "kubens";
  };
}
