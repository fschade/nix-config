{
  config,
  lib,
  ...
}: {
  options.local.webApps = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    example = ["opentalk" "pushover"];
    description = "web-app slugs to build on this host (empty = all in custom/web-apps).";
  };

  config.environment.etc."web-app/apps".text =
    lib.concatStringsSep "\n" config.local.webApps;
}
