{ isGraphical, isMinimal, inputs, devenv }:
{ pkgs, ... }:
let
  constants = import ./constants.nix;
in
{
  _module.args.common = {
    inherit (constants) authorizedKeys cacheSubstituters trustedPublicKeys;
    inherit (pkgs.stdenv) isLinux isDarwin;
    inherit isGraphical;
    inherit isMinimal;
    email = "benaduggan@gmail.com";
    firstName = "Ben";
    lastName = "Duggan";
    username = "bduggan";
    stateVersion = "24.05";

    jacobi = inputs.jacobi.packages.${pkgs.system};
    kwbauson = inputs.kwbauson.packages.${pkgs.system};
    inherit (devenv.packages.${pkgs.system}) devenv;
    agenix = inputs.agenix.packages.${pkgs.system}.default;


  };
}
