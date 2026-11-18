# services.strata: local OpenAI/Anthropic-compatible API for Qwen3.8-Flash-Next (125B MoE),
# using jacobi's `strata.ampere` package (cached in https://cache.g7c.us for sm_86 / RTX 3090).
#
# strata-prepare regenerates <stateDir>/strata-<tag>.json on start, and preStart layers
# extraEngineArgs, sampling, mcpServers, and apiKeyFile into <stateDir>/config.json.
{ pkgs, config, lib, nixpkgs-beast-pkgs, ... }:
let
  cfg = config.services.strata;
  pkg = nixpkgs-beast-pkgs.strata;

  familyTag = {
    qwen = "";
    swift = "swift-";
    abliterated = "abliterated-";
    coder = "coder-";
  }.${cfg.family};
  tag = "${familyTag}${cfg.model}";
  preparedConfig = "${cfg.stateDir}/strata-${lib.toLower tag}.json";
  runConfig = "${cfg.stateDir}/config.json";

  prepareArgs = [
    "--yes"
    "--family"
    cfg.family
    "--model"
    cfg.model
    "--context"
    (toString cfg.context)
    "--host"
    cfg.host
    "--port"
    (toString cfg.port)
    "--no-browser"
    "--data-dir"
    (toString cfg.stateDir)
  ]
  ++ lib.optionals (cfg.gpu != null) [ "--gpu" cfg.gpu ]
  ++ lib.optionals (cfg.lowRam != null) [ "--low-ram" cfg.lowRam ]
  ++ lib.optionals (cfg.ggufDir != null) [ "--gguf-dir" (toString cfg.ggufDir) ];

  patchConfigScript = pkgs.writeText "strata-patch-config.py" ''
    import json
    import os
    import shlex
    import stat
    import sys
    from pathlib import Path

    src_path = Path(sys.argv[1])
    dst_path = Path(sys.argv[2])
    cfg = json.loads(src_path.read_text(encoding="utf-8-sig"))

    extra_raw = ${builtins.toJSON cfg.extraEngineArgs}
    extra = [tok for item in extra_raw for tok in shlex.split(item)]
    override_flags = {
        extra[i]
        for i in range(len(extra) - 1)
        if extra[i].startswith("--") and not extra[i + 1].startswith("--")
    }
    cleaned = []
    skip = False
    base_args = cfg.get("args", [])
    for i, tok in enumerate(base_args):
        if skip:
            skip = False
            continue
        if tok in override_flags and i + 1 < len(base_args) and not base_args[i + 1].startswith("--"):
            skip = True
            continue
        cleaned.append(tok)
    cfg["args"] = cleaned + extra

    sampling = ${builtins.toJSON cfg.sampling}
    if sampling:
        cfg["sampling"] = sampling

    mcp_servers = ${builtins.toJSON cfg.mcpServers}
    if mcp_servers:
        cfg["mcp_servers"] = mcp_servers

    api_key_cred = Path("/run/credentials/strata.service/api-key")
    if ${if cfg.apiKeyFile != null then "True" else "False"} and api_key_cred.is_file():
        cfg["api_key"] = api_key_cred.read_text(encoding="utf-8").strip()

    dst_path.write_text(json.dumps(cfg, indent=2) + "\n", encoding="utf-8")
    os.chmod(dst_path, stat.S_IRUSR | stat.S_IWUSR)
  '';
in
{
  options.services.strata = {
    enable = lib.mkEnableOption "Strata, a local OpenAI/Anthropic-compatible API for Qwen3.8-Flash-Next (125B MoE)";

    family = lib.mkOption {
      type = lib.types.enum [ "qwen" "swift" "abliterated" "coder" ];
      default = "swift";
      description = ''
        Which model: `swift` (Swift 1.5, answers ~1.8x sooner for the same accuracy),
        `abliterated` (Swift 1.5 uncensored, SC117's re-quant; Q2_0/IQ2_XS/IQ3_XXS),
        `qwen` (the original Qwen3.8-Flash-Next) or `coder` (half the experts kept, code-focused).
      '';
    };

    model = lib.mkOption {
      type = lib.types.enum [ "Q2_0" "IQ2_XS" "IQ3_XXS" "IQ3_S" "IQ1_M" ];
      default = "IQ2_XS";
      description = ''
        Quantization size: Q2_0 (fastest), IQ2_XS (recommended), IQ3_XXS (better, slower),
        IQ3_S (best, qwen only, ~62 GB RAM), IQ1_M (coder only, ~32 GB RAM).
        strata-prepare refuses a quant the family does not publish.
      '';
    };

    context = lib.mkOption {
      type = lib.types.enum [ 8192 32768 65536 131072 204800 262144 393216 524288 1048576 ];
      default = 32768;
      description = ''
        Context window in tokens. From 64K on, the KV cache streams from RAM.
        Past 262144 (the trained length) strata-prepare turns yarn on by itself
        and derives the factor; extraEngineArgs can override.
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.path;
      example = "/mnt/massive/strata";
      description = ''
        Where the ~70 GB of model weights, the pack and config.json live. No default:
        it is the data mount, and the model does not fit on the root partition.
        A static `strata` user owns it (0750); the strata-initdir unit below makes it
        before the service starts, because systemd resolves ReadWritePaths= and
        WorkingDirectory= before any ExecStartPre of the service itself can.
      '';
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = ''
        Listen address: `127.0.0.1` this machine only, `0.0.0.0` also the LAN/tailnet,
        `::` all IPv6 interfaces. Passed to `strata serve` as `--host` and written into
        config.json, so the two cannot disagree. Non-loopback without apiKeyFile warns.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8015;
      description = ''
        TCP port, passed to `strata serve` as `--port` and written into config.json.
        8015 is the port services.llama-cpp is configured with here too; that service stays
        off while strata is on, so one of the two holds it.
      '';
    };

    apiKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        File holding the API key the server requires on /v1/*, read through a systemd
        credential so it never appears in the unit or in `ps`. Use something like
        /run/secrets/... : a path in the Nix store is readable by every user on the
        machine. Unset: no key, and a non-loopback host then warns at eval time.
      '';
    };

    sampling = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = ''
        Sampling defaults for requests that leave the fields out. Copied into config.json
        verbatim and checked by the server when it starts, so a typo here shows up in the
        journal rather than at eval time.
        eg { temperature = 0.8; top_p = 0.95; top_k = 20; reasoning_effort = "low"; }
      '';
    };

    mcpServers = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "MCP server definitions written to config.json as `mcp_servers`.";
    };

    gpu = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "GPU selector written to config.json (null lets the engine pick the most-VRAM card).";
    };

    lowRam = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "auto" "on" "off" "resident" "mmap" ]);
      default = null;
      description = "Low-RAM expert mode (`auto`/`on`/`off`/`resident`/`mmap`), or null for strata-prepare's default.";
    };

    ggufDir = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Directory of pre-downloaded GGUF shards to use instead of downloading from Hugging Face.";
    };

    hfTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "File holding a Hugging Face token for downloads, passed via a systemd credential.";
    };

    extraEngineArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Extra arguments appended to the engine command line, e.g. `[ "--kv q4_0" "--prompt-cache-spread" ]`.
        Each item is split into argv tokens with shell quoting rules, so a flag and its value
        may sit in one item or in two. They go after the generated arguments (replacing any matching
        single-value flag from strata-prepare), so this is how a machine overrides something
        strata-prepare picked for it. An unknown flag is an engine that does not start: check
        `strata-engine --help` of the pinned version before adding one.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    warnings = lib.optionals
      (cfg.apiKeyFile == null && !(lib.elem cfg.host [ "127.0.0.1" "localhost" "::1" ]))
      [
        ''
          services.strata: host = "${cfg.host}" with apiKeyFile unset exposes the API on port
          ${toString cfg.port} without authentication. Set apiKeyFile or host = "127.0.0.1".
        ''
      ];

    # Static user so weight ownership persists and /dev/nvidia* access isn't blocked by DynamicUser.
    users.groups.strata = { };
    users.users.strata = {
      isSystemUser = true;
      group = "strata";
      description = "Strata inference service";
    };

    # Create stateDir before strata.service builds its mount namespace (ReadWritePaths/WorkingDirectory).
    systemd.services.strata-initdir = {
      description = "Create the Strata state directory ${cfg.stateDir}";
      requiredBy = [ "strata.service" ];
      before = [ "strata.service" ];
      unitConfig.RequiresMountsFor = [ cfg.stateDir ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.coreutils}/bin/install -d -o strata -g strata -m 0750 ${lib.escapeShellArg cfg.stateDir}";
      };
    };

    systemd.services.strata = {
      description = "Strata: Qwen3.8-Flash-Next (125B MoE) local inference API";
      documentation = [ "https://github.com/Niko1221/Strata" ];
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = [ pkg config.hardware.nvidia.package ];

      environment = {
        HOME = toString cfg.stateDir;
        STRATA_INSTALL_DIR = toString cfg.stateDir;
        PYTHONUNBUFFERED = "1";
      };

      # Bound retries so a broken config fails instead of looping forever with TimeoutStartSec=0.
      unitConfig = {
        StartLimitIntervalSec = 300;
        StartLimitBurst = 5;
      };

      preStart = ''
        set -euo pipefail
        ${lib.optionalString (cfg.hfTokenFile != null) ''
          if [[ -f /run/credentials/strata.service/hf-token ]]; then
            export HF_TOKEN="$(< /run/credentials/strata.service/hf-token)"
          fi
        ''}
        # Migrate any flat <stateDir>/models/*.gguf shards from the older prefetch layout
        # into <stateDir>/models/<tag>/ so strata-prepare reuses them without re-downloading.
        shopt -s nullglob
        flat_shards=(${lib.escapeShellArg "${cfg.stateDir}/models"}/*.gguf)
        if (( ''${#flat_shards[@]} > 0 )); then
          mkdir -p ${lib.escapeShellArg "${cfg.stateDir}/models/${tag}"}
          for f in "''${flat_shards[@]}"; do
            mv -n "$f" ${lib.escapeShellArg "${cfg.stateDir}/models/${tag}/"}
            [[ -f "$f.done" ]] && mv -n "$f.done" ${lib.escapeShellArg "${cfg.stateDir}/models/${tag}/"} || true
          done
        fi
        ${pkg}/bin/strata-prepare ${lib.escapeShellArgs prepareArgs}
        ${pkgs.python3}/bin/python3 ${patchConfigScript} ${lib.escapeShellArg preparedConfig} ${lib.escapeShellArg runConfig}
      '';

      serviceConfig = {
        Type = "simple";
        User = "strata";
        Group = "strata";
        TimeoutStartSec = "0"; # First start downloads ~70 GB and builds the pack
        LimitMEMLOCK = "infinity";
        WorkingDirectory = cfg.stateDir;
        UMask = "0077";
        Restart = "on-failure";
        RestartSec = 10;
        LoadCredential =
          lib.optional (cfg.apiKeyFile != null) "api-key:${cfg.apiKeyFile}"
          ++ lib.optional (cfg.hfTokenFile != null) "hf-token:${cfg.hfTokenFile}";
        ExecStart = lib.escapeShellArgs [
          "${pkg}/bin/strata"
          "serve"
          "--config"
          runConfig
          "--host"
          cfg.host
          "--port"
          (toString cfg.port)
        ];
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ cfg.stateDir ];
        ProtectHome = true;
        PrivateTmp = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
        LockPersonality = true;
      };
    };
  };
}
