{...}: {
  # shared profile for the pve boxes, identical on purpose. give a host its
  # own file again the day it diverges.
  imports = [
    ../home/os/linux.nix
    ../home/cli/core
    ../home/cli/ops.nix
  ];
}
