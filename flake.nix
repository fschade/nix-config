{
  description = "Nix configuration for my macOS + Linux machines (workstations & servers)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    # claude-code only, see overlays/default.nix
    nixpkgs-master.url = "github:nixos/nixpkgs/master";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    localias = {
      url = "github:peterldowns/localias";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # borrowed with thanks from github.com/google/elephant-goldfish-model (Apache-2.0)
    plugin-egm = {
      url = "github:google/elephant-goldfish-model";
      flake = false;
    };

    # borrowed with thanks from github.com/mksglu/context-mode (Elastic-2.0)
    plugin-context-mode = {
      url = "github:mksglu/context-mode";
      flake = false;
    };

    # borrowed with thanks from github.com/anthropics/claude-plugins-official (Apache-2.0)
    plugins-official = {
      url = "github:anthropics/claude-plugins-official";
      flake = false;
    };

    # borrowed with thanks from github.com/upstash/context7 (MIT)
    context7 = {
      url = "github:upstash/context7";
      flake = false;
    };

    # borrowed with thanks from github.com/banterny/claude-code-secret-guard (MIT)
    claude-secret-guard = {
      url = "github:banterny/claude-code-secret-guard";
      flake = false;
    };

    cc-safety-net = {
      url = "github:kenryu42/cc-safety-net";
      flake = false;
    };

    best-claude-hud = {
      url = "github:GaoSSR/best-claude-hud";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
      inputs.brew-src.follows = "brew-src";
    };
    brew-src = {
      url = "github:Homebrew/brew/7.0.13";
      flake = false;
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-nikitabobko = {
      url = "github:nikitabobko/homebrew-tap"; # aerospace
      flake = false;
    };
    homebrew-sozercan = {
      url = "github:sozercan/homebrew-repo"; # kaset
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    nix-darwin,
    ...
  } @ inputs: let
    inherit (nixpkgs) lib;

    vars = {
      user = {
        name = "fschade";
        fullName = "Florian Schade";
        email = "f.schade@icloud.com";
      };
    };

    user = vars.user.name;

    overlays = [(import ./overlays inputs)];

    systems = ["aarch64-darwin" "x86_64-linux"];
    forAllSystems = lib.genAttrs systems;

    homeHosts = {
      linux-default = {
        host = ./templates/linux-default.nix;
        system = "x86_64-linux";
      };
      darwin-default = {
        host = ./templates/darwin-default.nix;
        system = "aarch64-darwin";
      };

      pve-thinkcentre-01 = {
        host = ./hosts/pve-server.nix;
        system = "x86_64-linux";
      };
      pve-thinkcentre-02 = {
        host = ./hosts/pve-server.nix;
        system = "x86_64-linux";
      };
      pve-zimablade-01 = {
        host = ./hosts/pve-server.nix;
        system = "x86_64-linux";
      };
    };

    darwinHosts = {
      mac-studio = {
        host = ./hosts/mac-studio.nix;
        system = "aarch64-darwin";
      };
    };

    mkDarwin = {
      host,
      system,
    }:
      nix-darwin.lib.darwinSystem {
        inherit system;
        specialArgs = {inherit inputs self vars;};
        modules = [
          {nixpkgs.overlays = overlays;}
          host
          inputs.nix-homebrew.darwinModules.nix-homebrew
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = {inherit inputs vars;};
            };
          }
        ];
      };

    mkHome = {
      host,
      system,
    }:
      home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          inherit system overlays;
          config.allowUnfree = true;
        };
        extraSpecialArgs = {inherit inputs vars;};
        modules = [host];
      };
  in {
    darwinConfigurations = lib.mapAttrs (_: mkDarwin) darwinHosts;

    homeConfigurations =
      lib.mapAttrs' (name: v: lib.nameValuePair "${user}@${name}" (mkHome v)) homeHosts;

    checks = let
      pick = hosts: system: lib.filterAttrs (_: v: v.system == system) hosts;
      hostSystems =
        lib.unique (map (v: v.system) (lib.attrValues homeHosts ++ lib.attrValues darwinHosts));
    in
      lib.genAttrs hostSystems (system:
        lib.mapAttrs (name: _: self.darwinConfigurations.${name}.system) (pick darwinHosts system)
        // lib.mapAttrs (name: _: self.homeConfigurations."${user}@${name}".activationPackage)
        (pick homeHosts system));

    devShells = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system overlays;};
    in {
      default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          mise # task runner
          lefthook # git hooks
          committed # the commit-msg hook lefthook installs below calls it
          gitleaks # secret scanning
          alejandra # nix formatter
          deadnix # dead-code linter
          statix # nix linter
          shellcheck # shell linter, the scripts and the claude hooks
          jq
          git
        ];
        shellHook = ''
          lefthook install >/dev/null || echo "lefthook install failed, git hooks are not wired" >&2
        '';
      };
    });
  };
}
