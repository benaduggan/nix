{
  inputs = {
    #nixpkgs.url = "nixpkgs/73de017ef2d18a04ac4bfd0c02650007ccb31c2a";
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixos-hardware.flake = true;
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    kwbauson = {
      url = "github:kwbauson/cfg";
      inputs = {
        home-manager.follows = "home-manager";
        nix-darwin.follows = "nix-darwin";
        nixos-hardware.follows = "nixos-hardware";
        nixpkgs.follows = "nixpkgs";
      };
    };

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
    devenv.url = "github:cachix/devenv/latest";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # deadnix: skip
  outputs = inputs@{ self, agenix, nixpkgs, nix-darwin, home-manager, kwbauson, jacobi, devenv, nixos-hardware, vscode-server, nixos-generators }:
    let
      inherit (nixpkgs) lib;
      inherit (nix-darwin.lib) darwinSystem;
      inherit (nixpkgs.lib) mapAttrs attrValues optionalAttrs singleton;

      # Configuration for `nixpkgs`
      nixpkgsConfig = {
        config = { allowUnfree = true; };
        overlays = attrValues self.overlays ++ singleton (
          # Sub in x86 version of packages that don't build on Apple Silicon yet
          # These might get updated, when that happens, just remove them from that list
          final: prev: (optionalAttrs (prev.stdenv.system == "aarch64-darwin") {
            inherit (final.pkgs-x86)
              purescript;
          })
        ) ++ import ./overlays.nix;
      };

    in
    {
      packages = lib.genAttrs lib.systems.flakeExposed (system:
        let
          pkgs = import nixpkgs (nixpkgsConfig // { inherit system; });
        in
        pkgs // {
          default = {
            x86_64-linux = pkgs.linkFarmFromDrvs "build" (attrValues (mapAttrs (_: value: value.config.system.build.toplevel) self.nixosConfigurations));
            x86_64-darwin = (self.darwinConfigurations.us-mbp-benduggan.override { system = "x86_64-darwin"; }).system;
            aarch64-darwin = self.darwinConfigurations.us-mbp-benduggan.system;
          }.${system};
        }
      );

      darwinConfigurations =
        let
          common = import ./common.nix { isGraphical = true; isMinimal = false; inherit inputs; inherit devenv; };
        in
        {
          us-mbp-benduggan = lib.makeOverridable darwinSystem {
            system = "aarch64-darwin";
            modules = [
              common
              ./machines/paper/darwin-configuration.nix
              home-manager.darwinModules.home-manager
              {
                nixpkgs = nixpkgsConfig;
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.benduggan = { imports = [ common ./home ]; };
              }
            ];
          };

          magic-mbp = lib.makeOverridable darwinSystem {
            system = "aarch64-darwin";
            modules = [
              common
              ./machines/magic-mbp/darwin-configuration.nix
              home-manager.darwinModules.home-manager
              {
                nixpkgs = nixpkgsConfig;
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.bduggan = { imports = [ common ./home ]; };
              }
            ];
          };
        };

      nixosConfigurations.bduggan-framework =
        let
          common = import ./common.nix { isGraphical = true; isMinimal = false; inherit inputs; inherit devenv; };
        in
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            common
            ./machines/framework/configuration.nix
            nixos-hardware.nixosModules.framework-11th-gen-intel
            vscode-server.nixosModule
            (_: {
              services.vscode-server.enable = true;
            })
            home-manager.nixosModules.home-manager
            {
              home-manager.useUserPackages = true;
              home-manager.useGlobalPkgs = true;
              home-manager.users.bduggan = {
                imports = [
                  common
                  ./home
                ];
              };
            }
          ];
        };

      nixosConfigurations.home-server =
        let
          common = import ./common.nix { isGraphical = false; isMinimal = false;  inherit inputs; inherit devenv; };
        in
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            common
            agenix.nixosModules.default
            ./machines/home-server/configuration.nix
            vscode-server.nixosModule
            (_: {
              services.vscode-server.enable = true;
            })
            home-manager.nixosModules.home-manager
            {
              home-manager.useUserPackages = true;
              home-manager.useGlobalPkgs = true;
              home-manager.users.bduggan = {
                imports = [
                  common
                  ./home
                ];
              };
            }
          ];
        };

      nixosConfigurations.bduggan-desktop =
        let
          common = import ./common.nix { isGraphical = false; isMinimal = false;  inherit inputs; inherit devenv; };
        in
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            common
            agenix.nixosModules.default
            ./machines/desktop/configuration.nix
            vscode-server.nixosModule
            (_: {
              services.vscode-server.enable = true;
            })
            home-manager.nixosModules.home-manager
            {
              home-manager.useUserPackages = true;
              home-manager.useGlobalPkgs = true;
              home-manager.users.bduggan = {
                imports = [
                  common
                  ./home
                ];
              };
            }
          ];
        };

      nixosConfigurations.digdugdev =
        let
          common = import ./common.nix { isGraphical = false; isMinimal = true;  inherit inputs; inherit devenv; };
        in
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            common
            agenix.nixosModules.default
            ./machines/digdugdev/configuration.nix
            home-manager.nixosModules.home-manager
            vscode-server.nixosModule
            (_: {
              services.vscode-server.enable = true;
            })
            {
              home-manager.useUserPackages = true;
              home-manager.useGlobalPkgs = true;
              home-manager.users.bduggan = {
                imports = [
                  common
                  ./home
                ];
              };
            }
          ];
        };

      do-builder = nixos-generators.nixosGenerate {
        system = "x86_64-linux";
        format = "do";
        modules = [
          ./generators/do-builder/configuration.nix
        ];
      };

      overlays = {
        apple-silicon = _final: prev: optionalAttrs (prev.stdenv.system == "aarch64-darwin") {
          # Useful on Macs with Apple Silicon
          # Adds access to x86 packages system is running Apple Silicon
          pkgs-x86 = import nixpkgs {
            system = "x86_64-darwin";
            inherit (nixpkgsConfig) config;
          };
        };
      };
    };
}
