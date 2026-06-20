{
  self,
  vars,
  ...
}: {
  # touch ID for sudo (useful on every Mac, incl. headless servers)
  security.pam.services.sudo_local.touchIdAuth = true;

  system = {
    primaryUser = vars.user.name;
    stateVersion = 6;
    configurationRevision = self.rev or self.dirtyRev or null;
  };
}
