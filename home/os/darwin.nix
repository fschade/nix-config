{
  lib,
  vars,
  ...
}: {
  home.username = lib.mkDefault vars.user.name;
  home.homeDirectory = "/Users/${vars.user.name}";
}
