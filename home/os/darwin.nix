{
  lib,
  vars,
  ...
}: {
  # mkDefault so the nix-darwin hm integration (which sets the username from
  # the users attr) wins there; standalone home-manager needs it spelled out.
  home.username = lib.mkDefault vars.user.name;
  home.homeDirectory = "/Users/${vars.user.name}";
}
