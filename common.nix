{ pkgs, inputs, isGraphical, ... }:
{
  _module.args.common = {
    inherit (pkgs.stdenv) isLinux isDarwin;
    inherit isGraphical;
    email = "benaduggan@gmail.com";
    firstName = "Ben";
    lastName = "Duggan";

    kwbauson = import inputs.kwbauson { inherit (pkgs) system; };
    jacobi = import inputs.jacobi { inherit (inputs) nixpkgs; inherit (pkgs) system; };
  };
}
