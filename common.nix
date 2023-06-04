{ isGraphical, isMinimal, inputs }:
{ pkgs, ... }:
{
  _module.args.common = {
    inherit (pkgs.stdenv) isLinux isDarwin;
    inherit isGraphical;
    inherit isMinimal;
    email = "benaduggan@gmail.com";
    firstName = "Ben";
    lastName = "Duggan";
    username = "bduggan";
    stateVersion = "23.05";

    kwbauson = import inputs.kwbauson { inherit (pkgs) system; };
    jacobi = import inputs.jacobi { inherit (inputs) nixpkgs; inherit (pkgs) system; };
    inherit (inputs.devenv.packages.${pkgs.system}) devenv;

    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGaNQuSPDW/dsgptFTuuQmEtMQbYOpifcUmcq5jA0Sy8"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDAQ6BX5+xivdRw7p5jvXlnbgpVk4xqYazb+bN7tvPrq"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJDt0C828UN+hwHBinQUXtOiOBB4apm5bEDK1XUVXVlU"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMhq0qLYZCcWbgpRel02St/AxCsx7K9aufhiKXzkG3TM"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBYRwtinqAt7J+VxULNTqWewFjG5P+ah1Sc8IvRqtnw"
    ];

    cacheSubstituters = [
      "https://cache.nixos.org/"
      "https://devenv.cachix.org"
    ];

    trustedPublicKeys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    ];
  };
}
