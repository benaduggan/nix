{ machineName, isGraphical, isMinimal, inputs, devenv }:
{ pkgs, ... }:
let
  constants = import ./constants.nix;
  sys = pkgs.stdenv.hostPlatform.system;
in
{
  _module.args.common = {
    inherit (constants) authorizedKeys authorizedKeysRec cacheSubstituters digdugdevKey trustedPublicKeys magicSubstituters magicTrustedPublicKeys communitySubstituters communityTrustedPublicKeys;
    inherit (pkgs.stdenv) isLinux isDarwin;
    inherit isGraphical;
    inherit isMinimal;
    inherit machineName;

    email = "benaduggan@gmail.com";
    firstName = "Ben";
    lastName = "Duggan";
    username = "bduggan";
    stateVersion = "25.11";
    darwinStateVersion = 6;

    jacobi = inputs.jacobi.packages.${sys};
    kwbauson = inputs.kwbauson.packages.${sys};
    inherit (devenv.packages.${sys}) devenv;
    agenix = inputs.agenix.packages.${sys}.default;

    nixSettings = with constants; {
      extra-substituters = cacheSubstituters ++ magicSubstituters ++ pkgs.lib.optionals (machineName == "homeServer") communitySubstituters;
      extra-trusted-public-keys = trustedPublicKeys ++ magicTrustedPublicKeys ++ pkgs.lib.optionals (machineName == "homeServer") communityTrustedPublicKeys;
      trusted-users = [ "bduggan" ];
      narinfo-cache-negative-ttl = 10;
      experimental-features = [ "nix-command" "flakes" ];
    };


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
