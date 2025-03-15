{ machineName, isGraphical, isMinimal, inputs, devenv }:
{ pkgs, ... }:
let
  constants = import ./constants.nix;
in
{
  _module.args.common = {
    inherit (constants) authorizedKeys authorizedKeysRec cacheSubstituters digdugdevKey trustedPublicKeys magicSubstituters magicTrustedPublicKeys;
    inherit (pkgs.stdenv) isLinux isDarwin;
    inherit isGraphical;
    inherit isMinimal;
    inherit machineName;

    email = "benaduggan@gmail.com";
    firstName = "Ben";
    lastName = "Duggan";
    username = "bduggan";
    stateVersion = "24.05";

    jacobi = inputs.jacobi.packages.${pkgs.system};
    kwbauson = inputs.kwbauson.packages.${pkgs.system};
    inherit (devenv.packages.${pkgs.system}) devenv;
    agenix = inputs.agenix.packages.${pkgs.system}.default;

    ports = {
      ssh = 22;
      http = 80;
      https = 443;

      grafana = 2342;
      prometheus = 2343;
      loki = 3100;
      home-assistant = 8123;
      prometheus_node_exporter = 9002;
      promtail = 9080;
    };

  };
}
