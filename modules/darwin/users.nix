{
  pkgs,
  my,
  ...
}: {
  users.users."${my.vars.user.name}" = {
    home = "/Users/${my.vars.user.name}";
  };
}
