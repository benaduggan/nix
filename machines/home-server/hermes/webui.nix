{ config, hermesCfg, ... }:
let
  inherit (hermesCfg) tailnetIp pookaUid;
in
{
  # hermes-webui publishes on tailscale0 and talks to pooka's Gateway API.
  systemd.services."podman-hermes-webui" = {
    after = [ "tailscaled.service" "podman-hermes-agent-pooka.service" ];
    requires = [ "tailscaled.service" ];
    wants = [ "podman-hermes-agent-pooka.service" ];
  };

  virtualisation.oci-containers.containers.hermes-webui = {
    # https://github.com/nesquena/hermes-webui
    # Browser UI for `pooka`. Routes chat turns, live streaming, and approvals
    # through pooka's Gateway Runs API instead of spawning a second in-process
    # agent. Reach it from any tailnet device at http://100.89.0.69:8790
    # (or http://home-server-1:8790 with MagicDNS).
    image = "ghcr.io/nesquena/hermes-webui:0.52.688";
    volumes = [
      "/var/lib/hermes-agent/pooka/hermes:/home/hermeswebui/.hermes"
      "/var/lib/hermes-agent/pooka/hermes/home:/home/hermeswebui/home"
    ];
    environment = {
      # Run as hermes-pooka's UID/GID so writes stay owned by the sandbox user.
      WANTED_UID = toString pookaUid;
      WANTED_GID = toString pookaUid;
      HERMES_WEBUI_STATE_DIR = "/home/hermeswebui/.hermes/webui";
      HERMES_WEBUI_DEFAULT_WORKSPACE = "/home/hermeswebui/home";
      # Delegate chat turns & interactive approvals to pooka's Gateway Runs API.
      HERMES_WEBUI_CHAT_BACKEND = "gateway";
      HERMES_WEBUI_GATEWAY_BASE_URL = "http://${tailnetIp}:8642";
      HERMES_WEBUI_GATEWAY_USE_RUNS_API = "true";
    };
    ports = [ "${tailnetIp}:8790:8787" ];
    environmentFiles = [ config.age.secrets.hermesWebui.path ];
    extraOptions = [
      "--tmpfs=/tmp:rw,nosuid,nodev,size=256m"
      "--security-opt=no-new-privileges:true"
    ];
  };
}
