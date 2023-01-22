{ pkgs, inputs, ... }:
{
  _module.args.common = {
    inherit (pkgs.stdenv) isLinux isDarwin;
    email = "benaduggan@gmail.com";
    firstName = "Ben";
    lastName = "Duggan";
    symbol = "ᛥ";

    kwbauson = import inputs.nixpkgs { inherit (inputs.kwbauson) overlays; inherit (pkgs) system; };
    jacobi = import inputs.jacobi { inherit (inputs) nixpkgs; inherit (pkgs) system; };
  };
}
