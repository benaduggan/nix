{ config, lib, pkgs, ... }:
let
  cfg = config.services.systemWatchdog;
  probeFile = "/var/lib/watchdog-probe/heartbeat";
in
{
  options.services.systemWatchdog = {
    enable = lib.mkEnableOption "hardware watchdog, kernel panic reboot, and root-disk liveness self-healing";

    runtimeWatchdogSec = lib.mkOption {
      type = lib.types.str;
      default = "2m";
      description = "Systemd RuntimeWatchdogSec hardware watchdog interval.";
    };

    rebootWatchdogSec = lib.mkOption {
      type = lib.types.str;
      default = "5m";
      description = "Systemd RebootWatchdogSec hardware watchdog timeout during reboot.";
    };

    panicRebootSeconds = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 10;
      description = "Seconds to wait before automatically rebooting on kernel panic (0 disables).";
    };

    disableNvmeApst = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Disable NVMe Autonomous Power State Transitions (nvme_core.default_ps_max_latency_us=0)
        to prevent controller lockups waking from deep power states on always-on hosts.
      '';
    };

    rootDiskProbe = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Periodically write and fsync a probe file on the root filesystem and reboot if it
          hangs or fails with I/O errors. Catches dead-storage lockups where PID 1 stays
          resident in RAM and continues petting the hardware watchdog.
        '';
      };

      interval = lib.mkOption {
        type = lib.types.str;
        default = "5min";
        description = "How often to run the root-disk liveness probe.";
      };

      bootDelay = lib.mkOption {
        type = lib.types.str;
        default = "15min";
        description = "Grace period after boot before running the first root-disk probe.";
      };

      timeout = lib.mkOption {
        type = lib.types.str;
        default = "120s";
        description = "Maximum time to wait for a single probe run before treating the root disk as hung.";
      };

      failureAction = lib.mkOption {
        type = lib.types.enum [
          "none"
          "reboot"
          "reboot-force"
          "reboot-immediate"
          "poweroff"
          "poweroff-force"
          "poweroff-immediate"
        ];
        default = "reboot-immediate";
        description = "Systemd FailureAction when the root-disk probe fails or times out.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.settings.Manager = {
      RuntimeWatchdogSec = cfg.runtimeWatchdogSec;
      RebootWatchdogSec = cfg.rebootWatchdogSec;
    };

    boot.kernel.sysctl."kernel.panic" = lib.mkIf (cfg.panicRebootSeconds > 0) cfg.panicRebootSeconds;

    boot.kernelParams = lib.optionals cfg.disableNvmeApst [
      "nvme_core.default_ps_max_latency_us=0"
    ];

    systemd.services.root-disk-watchdog = lib.mkIf cfg.rootDiskProbe.enable {
      description = "Probe root filesystem liveness and reboot if storage is wedged";
      unitConfig = {
        FailureAction = cfg.rootDiskProbe.failureAction;
      };
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        StateDirectory = "watchdog-probe";
        TimeoutStartSec = cfg.rootDiskProbe.timeout;
        TimeoutStopSec = "10s";
      };
      script = ''
        set -euo pipefail

        probe() {
          local err
          if err="$(${pkgs.coreutils}/bin/printf '%-63s\n' "$(${pkgs.coreutils}/bin/date -u +%s)" | LC_ALL=C ${pkgs.coreutils}/bin/dd of=${probeFile} bs=64 count=1 conv=notrunc,fsync 2>&1)"; then
            return 0
          fi
          if [[ "$err" == *"No space left on device"* ]]; then
            echo "root-disk-watchdog: root filesystem full (ENOSPC); skipping reboot" >&2
            return 0
          fi
          echo "root-disk-watchdog: probe failed: $err" >&2
          return 1
        }

        if ! probe; then
          ${pkgs.coreutils}/bin/sleep 10
          probe
        fi
      '';
    };

    systemd.timers.root-disk-watchdog = lib.mkIf cfg.rootDiskProbe.enable {
      description = "Periodic root filesystem liveness probe";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = cfg.rootDiskProbe.bootDelay;
        OnUnitActiveSec = cfg.rootDiskProbe.interval;
        AccuracySec = "30s";
      };
    };
  };
}
