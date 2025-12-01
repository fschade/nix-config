{vars, ...}: {
  imports = [
    ../home/os/darwin.nix
    ../home/cli/core
  ];

  home.username = vars.user.name;
}
