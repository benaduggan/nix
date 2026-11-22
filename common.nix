{ machineName, isGraphical, isMinimal, inputs }:
{ pkgs, ... }:
let
  constants = import ./constants.nix;
  sys = pkgs.stdenv.hostPlatform.system;
in
{
  _module.args.common = {
    inherit (constants) authorizedKeys authorizedKeysRec digdugdevKey tailscaleIp harmoniaUpstreams cacheUpstreams communityUpstreams;
    tailnetIp = constants.tailscaleIp.${machineName} or null;
    inherit (pkgs.stdenv.hostPlatform) isLinux isDarwin;
    inherit isGraphical;
    inherit isMinimal;
    inherit machineName;
    inherit (constants) homeServerVaultwardenArchiveDir desktopVaultwardenArchiveDir ardenVaultwardenArchiveDir frameworkVaultwardenArchiveDir;

    email = "benaduggan@gmail.com";
    firstName = "Ben";
    lastName = "Duggan";
    username = "bduggan";
    stateVersion = "25.11";
    darwinStateVersion = 6;

    jacobiPackages = inputs.jacobi.packages.${sys};
    jacobiLegacy = inputs.jacobi.legacyPackages.${sys};
    kwbauson = inputs.kwbauson.packages.${sys};
    agenix = inputs.agenix.packages.${sys}.default;

    nixSettings = {
      trusted-users = [ "bduggan" ];
      narinfo-cache-negative-ttl = 300;
      http-connections = 64;
      max-substitution-jobs = 32;
      download-buffer-size = 134217728; # 128 MiB
      connect-timeout = 5;
      fallback = true;
      experimental-features = [ "nix-command" "flakes" ];
    };


    ports = {
      ssh = 22;
      http = 80;
      https = 443;

      grafana = 2342;
      prometheus = 2343;
      loki = 3100;
      harmonia = 5000;
      ncro = 9180;
      home-assistant = 8123;
      terminus = 2300;
      prometheus_node_exporter = 9002;
      alloy = 12345;
    };

  };
}
