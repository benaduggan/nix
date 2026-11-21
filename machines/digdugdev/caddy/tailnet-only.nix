{ common, lib, ... }:
let
  home = common.tailscaleIp.homeServer;

  # Tailnet-only routes served under https://<name>.ts.digdug.dev
  routes = {
    pooka = "${home}:8790";
    chat = "${home}:8080";
    grafana = "${home}:2342";
    greenhouse = "${home}:7000";
  };

  routeHandlers = lib.concatStringsSep "\n" (lib.mapAttrsToList
    (name: target: ''
      @${name} host ${name}.ts.digdug.dev
      handle @${name} {
        reverse_proxy ${target}
      }
    '')
    routes);
in
{
  # Tailnet-only wildcard (*.ts.digdug.dev -> 100.113.75.95 via DO DNS-01)
  services.caddy.virtualHosts."*.ts.digdug.dev".extraConfig = ''
    bind ${common.tailnetIp}
    tls {
      dns digitalocean {env.DO_AUTH_TOKEN}
    }

    ${routeHandlers}

    handle {
      abort
    }
  '';
}
