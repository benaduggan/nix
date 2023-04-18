{
  inputs = {
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    kwbauson.url = "github:kwbauson/cfg";
    jacobi.url = "github:jpetrucciani/nix";
    jacobi.flake = false;
    vscode-server.url = "github:msteen/nixos-vscode-server";
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, home-manager, kwbauson, jacobi, nixos-hardware, vscode-server }:
    let
      inherit (nix-darwin.lib) darwinSystem;
      inherit (nixpkgs.lib) attrValues optionalAttrs singleton genAttrs systems;

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

      default_module = { imports = [ ./common.nix ]; _module.args = { inherit inputs; }; };
    in
    {

      packages = genAttrs systems.flakeExposed (system: import nixpkgs (nixpkgsConfig // { inherit system; }) // {
        default = {
          x86_64-linux = self.nixosConfigurations.bduggan-framework.config.system.toplevel;
          aarch64-darwin = self.darwinConfigurations.us-mbp-bduggan.system;
        }.${system};
      });

      darwinConfigurations = {
        us-mbp-bduggan = darwinSystem {
          system = "aarch64-darwin";
          modules = [
            ./machines/paper/darwin-configuration.nix
            home-manager.darwinModules.home-manager
            {
              nixpkgs = nixpkgsConfig;
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.bduggan = {
                imports = [
                  default_module
                  ./home
                ];
              };
            }
          ];
        };
      };

      nixosConfigurations.bduggan-framework = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./machines/framework/configuration.nix
          nixos-hardware.nixosModules.framework
          vscode-server.nixosModule
          ({ config, pkgs, ... }: {
            services.vscode-server.enable = true;
          })
          home-manager.nixosModules.home-manager
          {
            home-manager.useUserPackages = true;
            home-manager.users.bduggan = {
              imports = [
                default_module
                ./home
              ];
            };
          }
        ];
      };

      overlays = {
        apple-silicon = final: prev: optionalAttrs (prev.stdenv.system == "aarch64-darwin") {
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
