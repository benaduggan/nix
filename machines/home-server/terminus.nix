# TRMNL Terminus (bring-your-own-server TRMNL server) — https://github.com/usetrmnl/terminus
# Mirrors upstream compose.yml (web + sidekiq worker + postgres + valkey) using the
# prebuilt ghcr image, pinned. Devices (jailbroken Kindles) talk to the web container.
{ common, config, ... }:

let
  terminusImage = "ghcr.io/usetrmnl/terminus:0.82.0";
  webPort = common.ports.terminus;
  dbPort = 5433; # host postgres already owns 5432
  kvPort = 6379;
  # Must EXACTLY match the host the Kindles dial in the TRMNL captive-portal setup.
  # trmnl1/trmnl2.digdug.dev are Caddy front-ends on digdugdev (tailscale) that
  # reverse-proxy here; either subdomain works as the device custom host.
  apiUri = "https://trmnl1.digdug.dev";
  appEnv = {
    HANAMI_PORT = toString webPort;
    API_URI = apiUri;
  };
  appVolumes = [
    "terminus-fonts:/app/public/fonts"
    "terminus-fonts:/usr/share/fonts/terminus"
    "terminus-uploads:/app/public/uploads"
  ];
in
{
  age.secrets.terminus = {
    file = ../../secrets/terminus.age;
    mode = "644";
  };

  virtualisation.oci-containers.containers = {
    terminus = {
      image = terminusImage;
      # APP_SETUP=true makes the entrypoint run migrations/asset setup (same as compose.yml's web service)
      environment = appEnv // { APP_SETUP = "true"; };
      # APP_SECRET, POSTGRES_PASSWORD, DATABASE_URL, KEYVALUE_URL come from the agenix env file
      environmentFiles = [ config.age.secrets.terminus.path ];
      volumes = appVolumes;
      extraOptions = [ "--network=host" "--init" ];
      restartPolicy = "unless-stopped";
    };

    terminus-worker = {
      image = terminusImage;
      cmd = [ "bundle" "exec" "sidekiq" "-r" "./config/sidekiq.rb" ];
      environment = appEnv;
      environmentFiles = [ config.age.secrets.terminus.path ];
      volumes = appVolumes;
      extraOptions = [ "--network=host" "--init" ];
      restartPolicy = "unless-stopped";
    };

    terminus-db = {
      image = "postgres:18.7-alpine";
      environment = {
        POSTGRES_USER = "terminus";
        POSTGRES_DB = "terminus";
      };
      # POSTGRES_PASSWORD comes from the agenix env file
      environmentFiles = [ config.age.secrets.terminus.path ];
      # non-default port since host postgres owns 5432; loopback-only under host networking
      cmd = [ "-p" (toString dbPort) "-c" "listen_addresses=127.0.0.1" ];
      volumes = [ "terminus-db-data:/var/lib/postgresql" ];
      extraOptions = [ "--network=host" ];
      restartPolicy = "unless-stopped";
    };

    terminus-kv = {
      image = "valkey/valkey:9.1-alpine";
      cmd = [
        "valkey-server"
        "--port" (toString kvPort)
        "--bind" "127.0.0.1"
        "--maxmemory" "256mb"
        "--maxmemory-policy" "noeviction"
      ];
      volumes = [ "terminus-kv-data:/data" ];
      extraOptions = [ "--network=host" ];
      restartPolicy = "unless-stopped";
    };
  };
}
