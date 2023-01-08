{
  inputs = {
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    kwbauson.url = "github:kwbauson/cfg";
    jacobi.url = "github:jpetrucciani/nix";
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, home-manager, kwbauson, jacobi }:
    let
      inherit (nix-darwin.lib) darwinSystem;
      inherit (nixpkgs.lib) attrValues makeOverridable optionalAttrs singleton;

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
        ) ++ import ../../nixpkgs/overlays.nix;
      };
    in
    {
      # My `nix-darwin` configs
      darwinModules = { };
      darwinConfigurations = rec {
        Benjamins-MacBook-Pro = darwinSystem {
          system = "aarch64-darwin";
          modules = attrValues self.darwinModules ++ [
            # Main `nix-darwin` config
            ./darwin-configuration.nix
            # `home-manager` module
            home-manager.darwinModules.home-manager
            {
              nixpkgs = nixpkgsConfig;

              # `home-manager` config
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.bduggan = {
                imports = [
                  { _module.args = { inherit inputs; }; }
                  ./home.nix
                ];
              };
            }
          ];
        };
      };

      # Overlays --------------------------------------------------------------- {{{
      overlays = {
        # jacobi = final: prev: {
        #     jacobi = import inputs.jacobi { inherit (prev) pkgs; };
        #   };

        # kwbauson = final: prev: {
        #     kwbauson = import inputs.kwbauson { inherit (prev) pkgs; };
        #   };

        # Overlay useful on Macs with Apple Silicon
        apple-silicon = final: prev: optionalAttrs (prev.stdenv.system == "aarch64-darwin") {
          # Add access to x86 packages system is running Apple Silicon
          pkgs-x86 = import nixpkgs {
            system = "x86_64-darwin";
            inherit (nixpkgsConfig) config;
          };
        };
      };
    };
}
