{ config, lib, pkgs, hermesCfg, ... }:
let
  inherit (hermesCfg) tailnetIp pookaUid;

  firecrawlPythonPath = lib.makeSearchPath pkgs.python314.sitePackages [
    pkgs.python314Packages.firecrawl-py
    pkgs.python314Packages.nest-asyncio
  ];

  hermesWithExtras = pkgs.symlinkJoin {
    name = "hermes-agent-with-extras";
    paths = [ pkgs.hermes-agent ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for bin in hermes hermes-agent; do
        rm "$out/bin/$bin"
        makeWrapper "${pkgs.hermes-agent}/bin/$bin" "$out/bin/$bin" \
          --suffix PYTHONPATH : "${firecrawlPythonPath}"
      done
    '';
  };
in
{
  services.hermes-agent = {
    enable = true;
    instances.pooka = {
      package = hermesWithExtras;
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
        bzip2
        claude-code
        codex
        curl
        diffutils
        fd
        ffmpeg
        file
        gh
        git
        gnumake
        gnutar
        gzip
        jq
        less
        nano
        netcat-gnu
        nodejs_22
        openssh
        p7zip
        patch
        procps
        python3
        ripgrep
        socat
        sqlite
        tree
        ungoogled-chromium
        unzip
        uv
        wget
        which
        xz
        yq-go
        zip
        zstd
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
          default = "qwen3.8-flash-next-iq3_s";
          provider = "custom";
          base_url = "http://beast:8015/v1";
          api_key = "\${env:BEAST_API_KEY}";
          context_length = 131072;
        };

        agent = {
          max_turns = 150;
          gateway_timeout = 1800;
          reasoning_effort = "low";
          tool_use_enforcement = [ "qwen" ];
          intent_ack_continuation = true;
          environment_hint = lib.concatStringsSep " " [
            "You run inside an isolated rootless Podman/Nix container with no host filesystem mounts."
            "Obsidian notes are ONLY accessible through the `executor` MCP tools — never via local `/home/bduggan/...` paths."
            "Pre-installed CLI tools already on PATH include: ffmpeg, ffprobe, chromium, python3, uv, uvx, node, npm, npx, bun, bunx, git, gh, rg, fd, jq, yq, sqlite3, curl, wget, which, file, tar, ps, and nix."
            "You can install/use additional tools on demand via `nix-shell -p <pkg>`, `uvx`, or `bunx`."
          ];
        };

        # Keep MCP tools eager instead of wrapping `executor` inside the
        # `tool_search`/`tool_call` JSON-in-JSON bridge (which causes nested
        # JSON escaping errors on local quantized models).
        tools.tool_search.enabled = "off";

        tool_loop_guardrails.hard_stop_enabled = true;

        # Keep background compaction/title calls fast and non-thinking so they
        # don't stall Strata's single inference slot.
        auxiliary = {
          compression = {
            reasoning_effort = "none";
            timeout = 300;
          };
          title_generation.reasoning_effort = "none";
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

        # Auto-approve commands inside this isolated rootless Podman sandbox
        # (read-only rootfs, no host mounts, no capabilities) so pooka can work
        # autonomously without stalling on interactive prompts or burning extra
        # smart-approval guardian calls on beast.
        approvals = {
          mode = "off";
          unattended_mode = "approve";
          cron_mode = "approve";
          single_query_mode = "approve";
          deny = [
            "git push --force*"
            "git push -f*"
          ];
          timeout = 300;
          mcp_reload_confirm = false;
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
