{
  config,
  pkgs,
  ...
}: {
  xdg.configFile."proxychains/proxychains.conf".source = ./proxychains.conf;
}
