{ common, config, lib, ... }:
let
  inherit (common) isLinux machineName ports;
  ncroUrl = "http://localhost:${toString ports.ncro}";
  upstreams =
    lib.optionals (machineName != "homeServer") common.harmoniaUpstreams
    ++ common.cacheUpstreams
    ++ lib.optionals (machineName == "homeServer") common.communityUpstreams;
in
{
  services.ncro = {
    enable = lib.mkDefault true;
    port = ports.ncro;
    settings = {
      cache.negative_ttl = "${toString config.nix.settings.narinfo-cache-negative-ttl}s";
      inherit upstreams;
    } // lib.optionalAttrs isLinux {
      logging.timestamps = false;
    };
  } // lib.optionalAttrs isLinux {
    socketActivation = true;
  };

  nix.settings = {
    substituters = lib.mkForce [ ncroUrl ];
    extra-substituters = lib.mkForce [ ];
    narinfo-cache-meta-ttl = 10;
    narinfo-cache-positive-ttl = 10;
  };
}
