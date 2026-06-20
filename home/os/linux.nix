{vars, ...}: {
  home.username = vars.user.name;
  home.homeDirectory = "/home/${vars.user.name}";
}
