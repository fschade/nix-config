{
  config,
  lib,
  ...
}: {
  # which apps from custom/web-apps/ this host builds. empty = all, so a
  # single-mac setup needs nothing here. see tools/web-app/README.md.
  options.local.webApps = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    example = ["opentalk" "pushover"];
    description = "web-app slugs to build on this host (empty = all in custom/web-apps).";
  };

  # the swift builder reads this, one slug per line, empty file = build all.
  # keeps the source of truth in nix and the builder config-free.
  config.environment.etc."web-app/apps".text =
    lib.concatStringsSep "\n" config.local.webApps;
}
