{ config, pkgs, hermesCfg, ... }:
let
  inherit (hermesCfg) tailnetIp pookaUid;
in
{
  services.hermes-agent = {
    enable = true;
    instances.pooka = {
      uid = pookaUid;
      enableNix = true;
      pidsLimit = 2048;

      # Reap zombie child processes (e.g. Chromium/shell) and give headless
      # Chromium plenty of /dev/shm (Podman defaults to 64m).
      extraOptions = [ "--init" "--shm-size=1g" ];

      # Gateway API (8642) is published tailnet-only so hermes-webui (and
      # tailnet devices) can reach it; Webhook listener (8644) stays loopback-
      # only for pebble-hermes-shim.
      ports = [
        "${tailnetIp}:8642:8642"
        "127.0.0.1:8644:8644"
      ];

      # No host directories mounted (Obsidian is already exposed via MCP).
      # State and persistent home live under /var/lib/hermes-agent/pooka/hermes.
      mounts = { };

      # Declarative Nix toolchain baked into the container image's PATH.
      packages = with pkgs; [
        atool
        bun
        claude-code
        codex
        curl
        diffutils
        fd
        ffmpeg
        gh
        git
        gnumake
        jq
        nano
        netcat-gnu
        openssh
        p7zip
        patch
        python3
        ripgrep
        socat
        sqlite
        ungoogled-chromium
        unzip
        uv
        wget
        yq-go
        zip
      ];

      # WEBHOOK_SECRET comes from hermesWebhookSecret (shared with
      # pebble-hermes-shim); provider/Discord/ntfy/MCP tokens come from
      # hermesPooka so Podman injects them into the process environment before
      # hermes expands ${env:...} refs in /etc/hermes/config.yaml.
      environmentFiles = [
        config.age.secrets.hermesWebhookSecret.path
        config.age.secrets.hermesPooka.path
      ];

      # Rendered to immutable /etc/hermes/config.yaml (HERMES_MANAGED_DIR).
      # Unmanaged keys in /var/lib/hermes/config.yaml remain writable.
      settings = {
        model = {
          default = "Qwen3.8-27B-UD-Q4_K_XL";
          provider = "custom";
          base_url = "http://beast:8015/v1";
          api_key = "\${env:BEAST_API_KEY}";
        };

        agent = {
          max_turns = 150;
          gateway_timeout = 1800;
        };

        terminal = {
          backend = "local";
          cwd = "/var/lib/hermes/home";
          timeout = 180;
          persistent_shell = true;
        };

        web.backend = "firecrawl";

        # Use the container's Nix-packaged Chromium (container runs as UID 0
        # inside the rootless userns, so Playwright passes --no-sandbox).
        browser = {
          executable_path = "${pkgs.ungoogled-chromium}/bin/chromium";
          cloud_provider = "local";
          engine = "auto";
          auto_local_for_private_urls = true;
          inactivity_timeout = 120;
          command_timeout = 30;
        };

        # Interactive sessions (WebUI / Discord / CLI) prompt via smart
        # approvals; unattended Pebble ring webhooks auto-approve inside this
        # isolated rootless Podman sandbox.
        approvals = {
          mode = "smart";
          unattended_mode = "approve";
          cron_mode = "deny";
          timeout = 300;
          mcp_reload_confirm = true;
          destructive_slash_confirm = true;
        };

        discord = {
          require_mention = true;
          auto_thread = true;
          thread_require_mention = false;
          history_backfill = true;
          history_backfill_limit = 50;
          reactions = true;
          voice_fx.enabled = false;
        };

        gateway.api_server = {
          enabled = true;
          host = "0.0.0.0";
          port = 8642;
        };

        mcp_servers.executor = {
          url = "https://mcp.digdug.dev/mcp?mode=passthrough";
          headers.Authorization = "Bearer \${env:EXECUTOR_MCP_TOKEN}";
          enabled = true;
        };

        # Enable installed plugins declaratively so we bypass `hermes pm`'s
        # FHS `uv` binary download (aiohttp is already in Hermes's Nix env).
        plugins.enabled = [ "homeassistant" ];

        telemetry.shared_metrics = {
          enabled = false;
          send = false;
          offer_version = 2;
        };
      };
    };
  };

  # pooka publishes its Gateway API on the tailscale0 IP, so wait for tailscaled.
  systemd.services."podman-hermes-agent-pooka" = {
    after = [ "tailscaled.service" ];
    requires = [ "tailscaled.service" ];
  };
}
