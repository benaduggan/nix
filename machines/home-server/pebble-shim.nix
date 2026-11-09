{ config, lib, pkgs, ... }:

let
  pebbleShim = pkgs.buildGoModule {
    pname = "pebble-hermes-shim";
    version = "1.0.0";
    src = ./pebble-shim;
    vendorHash = null;
  };
in
{
  age.secrets.pebbleWebhookSecret = {
    file = ../../secrets/pebble-webhook-secret.age;
    mode = "0400";
    owner = "root";
    group = "root";
  };
  age.secrets.hermesWebhookSecret = {
    file = ../../secrets/hermes-webhook-secret.age;
    mode = "0400";
    owner = "bduggan";
    group = "users";
  };

  systemd.services.pebble-hermes-shim = {
    description = "Pebble Index webhook adapter for Hermes Gateway";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    environment = {
      LISTEN_ADDR = "0.0.0.0:8765";
      HERMES_WEBHOOK_URL = "http://127.0.0.1:8644/webhooks";
    };
    serviceConfig = {
      ExecStart = "${pebbleShim}/bin/pebble-hermes-shim";
      Restart = "on-failure";
      RestartSec = "2s";
      DynamicUser = true;
      LoadCredential = [
        "pebble-webhook-secret:${config.age.secrets.pebbleWebhookSecret.path}"
        "hermes-webhook-secret:${config.age.secrets.hermesWebhookSecret.path}"
      ];
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
      UMask = "0077";
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8765 ];
}
