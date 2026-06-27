{
  description = "Nix configuration for my macOS + Linux machines (workstations & servers)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # https://github.com/catppuccin/nix
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Prebuilt, auto-refreshing nix-index database (backs `comma`).
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Local HTTPS dev domains (e.g. myproject.test) with automatic certs +
    # /etc/hosts management. Not in nixpkgs, so pulled from upstream.
    localias = {
      url = "github:peterldowns/localias";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative Homebrew: installs brew itself and pins every tap as a flake
    # input (see modules/darwin/homebrew.nix). Source trees, not flakes.
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
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
    forAllSystems = nixpkgs.lib.genAttrs systems;

    mkHomeDarwin = {
      host,
      system ? "aarch64-darwin",
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
      system ? "x86_64-linux",
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
    darwinConfigurations = {
      mac-studio = mkHomeDarwin {host = ./hosts/mac-studio.nix;};
    };

    homeConfigurations = {
      # Generic machines (no host): any throwaway VM, cloud box, or CI runner.
      "${user}@linux-default" = mkHome {host = ./templates/linux-default.nix;};
      "${user}@darwin-default" = mkHome {
        host = ./templates/darwin-default.nix;
        system = "aarch64-darwin";
      };

      # Real Linux hosts.
      "${user}@pve-thinkcentre-01" = mkHome {host = ./hosts/pve-thinkcentre-01.nix;}; # 10.42.10.6
      "${user}@pve-thinkcentre-02" = mkHome {host = ./hosts/pve-thinkcentre-02.nix;}; # 10.42.10.7
      "${user}@pve-zimablade-01" = mkHome {host = ./hosts/pve-zimablade-01.nix;}; # 10.42.10.8
    };

    # Per-system checks: build each machine's config. The static gates
    # (fmt/lint/secrets) live in mise (`mise run check`); CI runs them there.
    # CI builds these per-runner (see .github/workflows/check.yml).
    checks = {
      aarch64-darwin = {
        mac-studio = self.darwinConfigurations.mac-studio.system;
        darwin-default = self.homeConfigurations."${user}@darwin-default".activationPackage;
      };
      x86_64-linux = {
        linux-default = self.homeConfigurations."${user}@linux-default".activationPackage;
        pve-thinkcentre-01 = self.homeConfigurations."${user}@pve-thinkcentre-01".activationPackage;
        pve-thinkcentre-02 = self.homeConfigurations."${user}@pve-thinkcentre-02".activationPackage;
        pve-zimablade-01 = self.homeConfigurations."${user}@pve-zimablade-01".activationPackage;
      };
    };

    devShells = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system overlays;};
    in {
      default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          mise # task runner
          lefthook # git hooks
          gitleaks # secret scanning
          alejandra # nix formatter
          deadnix # dead-code linter
          statix # nix linter
        ];
        # Wire up the git hooks on first entry (idempotent).
        shellHook = ''
          lefthook install >/dev/null 2>&1 || true
        '';
      };
    });
  };
}
