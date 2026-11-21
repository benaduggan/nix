{ lib, ... }:
let
  mkProxy = target: {
    extraConfig = ''
      reverse_proxy ${target}
    '';
  };

  securityHeaders = ''
    header {
      X-Content-Type-Options nosniff
      X-Frame-Options DENY
      Referrer-Policy strict-origin-when-cross-origin
    }
  '';

  # Simple reverse proxy passthroughs
  proxyHosts = lib.mapAttrs' (sub: target: lib.nameValuePair "${sub}.digdug.dev" (mkProxy target)) {
    # Push Notifications & Automations
    ntfy = "home-server-1:9090";
    n8n = "home-server-1:5678";
    litellm = "home-server-1:4000";
    mcp = "home-server-1:4788";
    trmnl = "home-server-1:2300";

    # Content Hosting
    audio = "beast:8000";
    books = "beast:8083";
    sink = "localhost:8080";
    padre = "pi-memes:42617";

    # Home Assistants
    "arden.ha" = "arden:8123";
    "springfield.ha" = "springfield:8123";
    "lake.ha" = "bduggan-desktop:8123";
    "fishers.ha" = "home-server-1:8123";
  };
in
{
  services.caddy.virtualHosts = proxyHosts // {
    "digdug.dev".extraConfig = ''
      root * /var/www/digdug.dev
      file_server
      encode gzip
      ${securityHeaders}
    '';

    "java.digdug.dev".extraConfig = ''
      root * /var/www/java
      file_server
    '';

    "remi-bday.digdug.dev".extraConfig = ''
      root * /var/www/remi-bday
      encode zstd gzip
      ${securityHeaders}
      file_server
    '';

    "assets.digdug.dev".extraConfig = ''
      root * /var/www/tldr
      encode zstd gzip
      header {
        Access-Control-Allow-Origin "*"
        Access-Control-Allow-Methods "GET, HEAD, OPTIONS"
        Access-Control-Allow-Headers "*"
      }
      @options method OPTIONS
      respond @options 204
      file_server
    '';

    "pebble.digdug.dev".extraConfig = ''
      @transcript path /transcript
      handle @transcript {
        reverse_proxy home-server-1:8765
      }

      # Brian's Pebble Index app, served by the pi-memes node on the tailnet.
      # handle_path strips the /padre/webhook prefix so the app can serve from its own root.
      handle_path /padre/webhook* {
        reverse_proxy pi-memes:8091
      }
    '';

    "http://board.digdug.dev".extraConfig = ''
      header {
        Cache-Control "no-cache, no-store, must-revalidate"
      }
      root * /var/www
      file_server
    '';

    "sec-board.digdug.dev".extraConfig = ''
      authorize with google_auth

      header {
        Cache-Control "no-cache, no-store, must-revalidate"
      }

      handle /upload* {
        reverse_proxy localhost:8787
      }

      handle {
        root * /var/www
        file_server
      }
    '';
  };
}
