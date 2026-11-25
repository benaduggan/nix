{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable-small";
    nixos-hardware = {
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    kwbauson = {
      url = "git+https://github.com/kwbauson/cfg?submodules=1";
      inputs = {
        home-manager.follows = "home-manager";
        nix-darwin.follows = "nix-darwin";
        nixos-hardware.follows = "nixos-hardware";
        nixpkgs.follows = "nixpkgs";
      };
    };
    flake-compat.url = "github:NixOS/flake-compat";
    flake-compat.flake = false;

    jacobi = {
      url = "github:jpetrucciani/nix";
      inputs = {
        home-manager.follows = "home-manager";
        nix-darwin.follows = "nix-darwin";
        nixos-hardware.follows = "nixos-hardware";
        # nixpkgs.follows = "nixpkgs";
      };
    };

    vscode-server.url = "github:msteen/nixos-vscode-server";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ncro = {
      url = "github:manic-systems/ncro";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pinned nixpkgs for working CUDA stack
    nixpkgs-pascal-cuda.url = "github:nixos/nixpkgs/35f1742e4f1470817ff8203185e2ce0359947f12";

    # Separate nixpkgs for beast's NVIDIA/CUDA deps (updated independently)
    nixpkgs-beast.url = "nixpkgs/nixos-unstable";
  };

  outputs = inputs@{ self, nixpkgs, nixpkgs-beast, nix-darwin, nixos-generators, ... }:
    let
      inherit (nixpkgs) lib;
      inherit (nix-darwin.lib) darwinSystem;
      inherit (nixpkgs.lib) mapAttrs attrValues optionalAttrs;

      pkgsFor = lib.genAttrs lib.systems.flakeExposed (system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            self.overlays.default
            (_final: _prev:
              optionalAttrs (inputs.jacobi.legacyPackages ? ${system}) {
                inherit (inputs.jacobi.legacyPackages.${system}.pkgs) hermes-agent pog;
              })
          ];
        }
      );

      beastPkgs = import nixpkgs-beast {
        system = "x86_64-linux";
        config = {
          allowUnfree = true;
          cudaCapabilities = [ "8.6" ];
        };
        overlays = [
          (final: prev:
            let
              strata = inputs.jacobi.legacyPackages.x86_64-linux.strata.ampere;
            in
            {
              sunshine = prev.sunshine.override {
                cudaSupport = true;
                inherit (final) cudaPackages;
              };
              inherit strata;
              strata-engine = strata.engine;
            })
        ];
      };

      mkDarwinHost = _name:
        { dir
        , machineName
        , user
        , system ? "aarch64-darwin"
        , extraModules ? [ ]
        }:
        let
          common = import ./common.nix {
            inherit machineName inputs;
            isGraphical = true;
            isMinimal = false;
          };
        in
        lib.makeOverridable darwinSystem {
          specialArgs = { inherit inputs; };
          modules = [
            { nixpkgs.pkgs = pkgsFor.${system}; }
            common
            ./modules/darwin-base.nix
            ./machines/${dir}/darwin-configuration.nix
            {
              home-manager.users.${user}.imports = [ common ./home ];
            }
          ] ++ extraModules;
        };

      mkNixosHost = _name:
        { dir
        , machineName
        , isGraphical
        , isMinimal
        , system ? "x86_64-linux"
        , user ? "bduggan"
        , specialArgs ? { }
        , extraModules ? [ ]
        }:
        let
          common = import ./common.nix { inherit machineName isGraphical isMinimal inputs; };
        in
        nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; } // specialArgs;
          modules = [
            { nixpkgs.pkgs = pkgsFor.${system}; }
            common
            ./modules/nixos-base.nix
            ./machines/${dir}/configuration.nix
            {
              home-manager.users.${user}.imports = [ common ./home ];
            }
          ] ++ extraModules;
        };

    in
    {
      packages = lib.genAttrs lib.systems.flakeExposed (system:
        let
          pkgs = pkgsFor.${system};
          mkNixosFarm = hosts:
            pkgs.linkFarmFromDrvs "build" (attrValues (mapAttrs (_: value: value.config.system.build.toplevel) hosts));
        in
        pkgs // {
          default = {
            x86_64-linux = mkNixosFarm self.nixosConfigurations;
            aarch64-darwin = self.darwinConfigurations.us-mbp-benduggan.system;
          }.${system};
          # Everything except `beast`, for the general CI build job.
          general = {
            x86_64-linux = mkNixosFarm (builtins.removeAttrs self.nixosConfigurations [ "beast" ]);
            aarch64-darwin = self.darwinConfigurations.us-mbp-benduggan.system;
          }.${system};
        } // optionalAttrs (system == "x86_64-linux") {
          beast = self.nixosConfigurations.beast.config.system.build.toplevel;
          requiredSubstitutes = {
            inherit (pkgs) firefox-unwrapped ungoogled-chromium ffmpeg;
          };
          requiredSubstitutes-beast = {
            inherit (beastPkgs) sunshine strata-engine;
            inherit (beastPkgs.cudaPackages) cudatoolkit cudnn cuda_cudart;
          };
        }
      );

      darwinConfigurations = mapAttrs mkDarwinHost {
        us-mbp-benduggan = {
          dir = "paper";
          machineName = "paper";
          user = "benduggan";
        };
        magic-mbp = {
          dir = "magic-mbp";
          machineName = "magicMbp";
          user = "bduggan";
        };
      };

      nixosConfigurations = mapAttrs mkNixosHost {
        bduggan-framework = {
          dir = "framework";
          machineName = "framework";
          isGraphical = true;
          isMinimal = false;
        };
        beast = {
          dir = "beast";
          machineName = "beast";
          isGraphical = true;
          isMinimal = false;
          specialArgs = { nixpkgs-beast-pkgs = beastPkgs; };
        };
        home-server = {
          dir = "home-server";
          machineName = "homeServer";
          isGraphical = false;
          isMinimal = false;
        };
        bduggan-desktop = {
          dir = "desktop";
          machineName = "lake";
          isGraphical = false;
          isMinimal = false;
        };
        arden = {
          dir = "arden";
          machineName = "arden";
          isGraphical = false;
          isMinimal = false;
        };
        digdugdev = {
          dir = "digdugdev";
          machineName = "digdugdev";
          isGraphical = false;
          isMinimal = true;
        };
        # wsl = {
        #   dir = "wsl";
        #   machineName = "wsl";
        #   isGraphical = false;
        #   isMinimal = true;
        #   user = "nixos";
        #   extraModules = [ inputs.nixos-wsl.nixosModules.wsl ];
        # };
      };

      do-builder = nixos-generators.nixosGenerate {
        system = "x86_64-linux";
        format = "do";
        modules = [
          ./generators/do-builder/configuration.nix
        ];
      };

      overlays = {
        default = import ./pkgs;
      };
    };
}
