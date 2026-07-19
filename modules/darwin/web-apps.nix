{
  config,
  lib,
  ...
}: {
  # per-host web-app selection. the builder (tools/web-app/web-app.swift, run from
  # scripts/deploy.sh) turns the app folders in custom/web-apps/ into /Applications
  # bundles. by default a host builds every app; a host that wants only a subset
  # lists the slugs here (folder name or app slug) and the builder builds exactly
  # those, pruning the managed apps it dropped. empty = all (the default), so a
  # single-mac setup needs nothing here.
  options.local.webApps = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    example = ["opentalk" "pushover"];
    description = "web-app slugs to build on this host (empty = all in custom/web-apps).";
  };

  # surface the resolved list to the builder as a plain file it reads on build:
  # one slug per line, an empty file means \"build everything\". keeps the source
  # of truth in nix, per host, while the swift builder stays config-free.
  config.environment.etc."web-app/apps".text =
    lib.concatStringsSep "\n" config.local.webApps;
}
