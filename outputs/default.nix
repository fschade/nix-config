{
  self,
  nixpkgs,
  ...
} @ inputs: let
  my = {
    vars = import ../vars {};
    lib = import ../lib {inherit nixpkgs;};
  };
in {
  darwinConfigurations."mac-studio" = inputs.nix-darwin.lib.darwinSystem {
    system = "aarch64-darwin";
    modules = [
      ../hosts/darwin-studio
      ./aarch64-darwin.nix
    ];
    specialArgs = {inherit inputs self my;};
  };
}
