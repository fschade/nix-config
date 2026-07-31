{
  self,
  vars,
  ...
}: {
  # touch id for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # macos app firewall on, plus stealth mode (ignore probes/pings)
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
