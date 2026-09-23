{
  self,
  vars,
  ...
}: {
  security.pam.services.sudo_local.touchIdAuth = true;

  networking.applicationFirewall = {
    enable = true;
    enableStealthMode = true;
  };

  time.timeZone = "Europe/Berlin";

  system = {
    primaryUser = vars.user.name;
    stateVersion = 6;
    configurationRevision = self.rev or self.dirtyRev or null;
  };
}
