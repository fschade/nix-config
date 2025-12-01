{vars, ...}: {
  users.users.${vars.user.name} = {
    home = "/Users/${vars.user.name}";
  };
}
