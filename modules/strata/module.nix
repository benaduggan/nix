# services.strata: the local OpenAI/Anthropic-compatible API for Qwen3.8-Flash-Next
# (125B MoE), written for the one host that runs it: beast (RTX 3090, 128 GB RAM).
# The package, the CUDA arch (sm_86) and the sandbox shape are fixed here instead of
# parameterised - another machine would want its own packages.nix call, not more options.
#
# ## config.json is generated, not managed
# The pre-start job (strata-prefetch) rewrites <stateDir>/config.json on every start from
# the options below, so these options are the only source of truth:
#   - edits made on the server's /config web page are lost at the next restart;
#   - avoid the web UI's "update & restart": strata_control/updater.py rewrites config.json
#     and picks a *random free* port, which then disagrees with the unit's --port (the unit
#     wins after the next restart). Rebuild the system instead.
# host and port also go on strata-serve's command line: the server binds the port from
# there (it never reads one out of config.json) and only falls back to config.json for
# --host, so a stale config.json cannot move the API somewhere nobody expects.
# When apiKeyFile is set, prefetch.py writes the key into that file in plaintext (the file
# is 0600, inside stateDir, which is 0750 strata).
# nixpkgs-beast-pkgs and inputs come from this machine's specialArgs in flake.nix.
{ pkgs, config, lib, inputs, nixpkgs-beast-pkgs, ... }:
let
  cfg = config.services.strata;

  # Built against beast's nixpkgs, not the system's: the engine's cudart has to match the
  # CUDA stack beast runs (same reason configuration.nix uses nixpkgs-beast-pkgs for
  # sunshine), and the kernels are compiled for its GPU. See packages.nix.
  strataPkgs = import ./packages.nix {
    pkgs = nixpkgs-beast-pkgs;
    src = inputs.strata;
    llamaSrc = inputs.llama-pinned;
  };
  pkg = strataPkgs.strata;

  # Everything the module pushes into config.json, as a list so no fragment has to worry
  # about shell line continuations.
  prefetchArgs = [
    "--family ${lib.escapeShellArg cfg.family}"
    "--model ${lib.escapeShellArg cfg.model}"
    "--context ${toString cfg.context}"
    "--data-dir \"${cfg.stateDir}\""
    "--emit-config \"${cfg.stateDir}/config.json\""
    "--engine ${lib.escapeShellArg (toString pkg.passthru.engine)}/bin/strata"
    "--host ${lib.escapeShellArg cfg.host}"
    # the port lands in config.json only so Strata's own helpers (calibration, the web
    # UI) aim at it; what actually binds is the --port on strata-serve's command line
    "--port ${toString cfg.port}"
  ]
  ++ lib.optionals (cfg.sampling != { }) [
    "--sampling-json ${pkgs.writeText "strata-sampling.json" (builtins.toJSON cfg.sampling)}"
  ]
  # the key itself goes in as a systemd credential, never on the command line (ps)
  # and never as a path in the store
  ++ lib.optional (cfg.apiKeyFile != null) ''--api-key-file "/run/credentials/strata.service/api-key"''
  ++ map (x: "--extra-arg ${lib.escapeShellArg x}") cfg.extraEngineArgs;
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
        strata-prefetch refuses a quant the family does not publish.
      '';
    };

    context = lib.mkOption {
      type = lib.types.enum [ 8192 32768 65536 131072 204800 262144 393216 524288 1048576 ];
      default = 32768;
      description = ''
        Context window in tokens. From 64K on, the KV cache streams from RAM.
        Past 262144 (the trained length) strata-prefetch turns yarn on by itself
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
        `::` all IPv6 interfaces. Passed to strata-serve as `--host` and written into
        config.json, so the two cannot disagree. Non-loopback without apiKeyFile warns.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8015;
      description = ''
        TCP port, passed as `--port` (strata-serve has no way to take it from config.json).
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
      default = { temperature = 0.8; top_p = 0.95; top_k = 20; reasoning_effort = "low"; };
      description = ''
        Sampling defaults for requests that leave the fields out. Copied into config.json
        verbatim and checked by the server when it starts, so a typo here shows up in the
        journal rather than at eval time.
      '';
    };

    extraEngineArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments appended to the engine command line (e.g. --kv q4_0).";
    };
  };

  config = lib.mkIf cfg.enable {
    # An OpenAI-compatible API on a reachable port with no key means anyone who can reach
    # it can spend this GPU. Warn rather than refuse: an unauthenticated port on the
    # tailnet is usually the intent, and there is no key file in this repo to require.
    warnings = lib.optionals
      (cfg.apiKeyFile == null && !(lib.elem cfg.host [ "127.0.0.1" "localhost" "::1" ]))
      [
        ''
          services.strata: host = "${cfg.host}" with apiKeyFile unset, so the API on port
          ${toString cfg.port} answers to anyone who can reach it. Set an apiKeyFile, or
          host = "127.0.0.1", if that is not intended.
        ''
      ];

    # A static user: a dynamic one's UID changes on every start (70 GB of weights would
    # need re-owning) and its strict device policy would keep the engine off /dev/nvidia*.
    users.groups.strata = { };
    users.users.strata = {
      isSystemUser = true;
      group = "strata";
      description = "Strata inference service";
    };

    systemd.tmpfiles.rules = [ "d ${cfg.stateDir} 0750 strata strata -" ];

    # Create the state dir ahead of strata.service, unsandboxed: the directory has to
    # exist before strata.service's mount namespace - which ReadWritePaths= and
    # WorkingDirectory= depend on - is built. This is what used to fail the boot with
    # status=226/NAMESPACE on the automounted data disk (27 times) until the restart loop
    # happened to win the race.
    systemd.services.strata-initdir = {
      description = "Create the Strata state directory ${cfg.stateDir}";
      # pulled in by strata.service, not wanted by multi-user.target: nothing to do while
      # the service is off
      requiredBy = [ "strata.service" ];
      before = [ "strata.service" ];
      # nofail + x-systemd.automount means the filesystem may not be up when the unit
      # queue reaches Strata; wait for it. RequiresMountsFor= is a [Unit] setting, so it
      # goes in unitConfig, not serviceConfig.
      unitConfig.RequiresMountsFor = [ cfg.stateDir ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.coreutils}/bin/install -d -o strata -g strata -m 0750 ${cfg.stateDir}";
      };
    };

    systemd.services.strata = {
      description = "Strata: Qwen3.8-Flash-Next (125B MoE) local inference API";
      documentation = [ "https://github.com/Niko1221/Strata" ];
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = [ pkg ];

      # Bound the retries: with Restart=on-failure and TimeoutStartSec=0 a start that is
      # genuinely broken looped forever instead of ever showing up as failed.
      unitConfig = {
        StartLimitIntervalSec = 300;
        StartLimitBurst = 5;
      };

      # Downloads/repairs the model files and rewrites config.json (resumable; everything
      # already present is skipped by a .done mark).
      preStart = toString (pkgs.writeShellScript "strata-prestart" ''
        set -euo pipefail
        exec ${pkg}/bin/strata-prefetch ${lib.concatStringsSep " \\\n  " prefetchArgs}
      '');

      serviceConfig = {
        Type = "simple";
        User = "strata";
        Group = "strata";
        # First start downloads ~70 GB and builds the pack: the default 90 s
        # TimeoutStartSec kills it mid-download (it is resumable, but converge in one pass)
        TimeoutStartSec = "0";
        WorkingDirectory = cfg.stateDir;
        UMask = "0077";
        Restart = "on-failure";
        RestartSec = 10;
        LoadCredential = lib.optional (cfg.apiKeyFile != null) "api-key:${cfg.apiKeyFile}";
        # host and port are always on the command line; see the note at the top of the file
        ExecStart = lib.concatStringsSep " " [
          "${pkg}/bin/strata-serve"
          "--engine strata"
          "--config ${cfg.stateDir}/config.json"
          "--host ${lib.escapeShellArg cfg.host}"
          "--port ${toString cfg.port}"
        ];
        NoNewPrivileges = true;
        # ProtectSystem=strict makes / read-only; the state dir is the one writable path
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
