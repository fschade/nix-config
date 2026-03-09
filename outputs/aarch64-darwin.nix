{
  inputs,
  my,
  ...
}: {
  imports = [
    ../modules/darwin
    inputs.home-manager.darwinModules.home-manager
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${my.vars.user.name} = {
      imports = [
        ../home/darwin
      ];
    };
    extraSpecialArgs = {
      inherit inputs my;
    };
  };
}
