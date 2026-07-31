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

    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # prebuilt nix-index db, auto refresh, backs `comma`
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # local https dev domains (e.g. myproject.test), auto certs + /etc/hosts. not in nixpkgs so from upstream.
    localias = {
      url = "github:peterldowns/localias";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # agent skills for claude code (see home/cli/claude). pinned as source trees
    # instead of installed with `npx skills add`, which drops unversioned copies
    # into ~/.agents. bump them with `mise run flake-update`.
    skills-mattpocock = {
      url = "github:mattpocock/skills"; # engineering flow skills
      flake = false;
    };
    skills-humanizer = {
      url = "github:blader/humanizer"; # strips ai writing tells
      flake = false;
    };
    # borrowed with thanks from github.com/trailofbits/skills (CC-BY-SA-4.0).
    skills-trailofbits = {
      url = "github:trailofbits/skills";
      flake = false;
    };
    # the first-party marketplace. we take single review subagents out of it,
    # not the plugin machinery.
    claude-plugins-official = {
      url = "github:anthropics/claude-plugins-official";
      flake = false;
    };

    # declarative homebrew: install brew and pin every tap as flake input (see
    # modules/darwin/homebrew.nix). the taps below carry `flake = false`, they are
    # source trees; nix-homebrew itself is a normal flake.
    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
      # nix-homebrew pins brew to a hard tag and lags behind releases, so brew
      # would read tap files it does not understand yet: a cask using a stanza
      # from a newer brew fails as "definition is invalid". `mise run brew-update`
      # only re-locks this pin, moving it means editing the tag below in the same
      # commit as the taps.
      #
      # the store path still reads brew-<tag>-patched with nix-homebrews tag,
      # it takes that string from its own lock. the tree inside is ours.
      inputs.brew-src.follows = "brew-src";
    };
    brew-src = {
      url = "github:Homebrew/brew/6.0.13";
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

    # the home-manager machines, single source of truth: drives both
    # homeConfigurations and the per-system checks below.
    homeHosts = {
      # generic machines (no host): throwaway vm, cloud box or ci runner.
      linux-default = {
        host = ./templates/linux-default.nix;
        system = "x86_64-linux";
      };
      darwin-default = {
        host = ./templates/darwin-default.nix;
        system = "aarch64-darwin";
      };

      # real linux hosts, all on the shared server profile.
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

    # the nix-darwin machines, same deal as homeHosts: drives both
    # darwinConfigurations and the checks.
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

    # per-system checks: build each machine config, derived from homeHosts and
    # darwinHosts so a new host cant slip past ci. static gates (fmt/lint/secrets)
    # live in mise (`mise run check`), ci builds these per-runner. filtered on the
    # declared system (not an evaluated one), so a runner never has to evaluate the
    # other platform's configs. the system list comes from the hosts too, so a
    # machine on a new platform gets its own checks group instead of none. ci
    # derives its matrix from these names, see .github/workflows/check.yml.
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
          # the claude hook tests run inside `mise run check`, so their tools
          # belong here too instead of being borrowed from the ambient PATH.
          jq
          git
        ];
        # install git hooks on first entry, idempotent. non-fatal (a broken
        # shellHook would block `nix develop`), but it says so: silently having
        # no hooks means every commit skips the gate.
        shellHook = ''
          lefthook install >/dev/null || echo "lefthook install failed, git hooks are not wired" >&2
        '';
      };
    });
  };
}
