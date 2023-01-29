{ pkgs, inputs, isGraphical, ... }:
{
  _module.args.common = {
    inherit (pkgs.stdenv) isLinux isDarwin;
    inherit isGraphical;
    email = "benaduggan@gmail.com";
    firstName = "Ben";
    lastName = "Duggan";

    kwbauson = import inputs.nixpkgs { inherit (inputs.kwbauson) overlays; inherit (pkgs) system; };
    jacobi = import inputs.jacobi { inherit (inputs) nixpkgs; inherit (pkgs) system; };
  };
}
