{ common, config, lib, pkgs, ... }:
let
  cfg = config.services.vaultwardenReplication;

  failoverWarningCss = pkgs.writeText "vaultwarden-failover-warning.css" ''
    #vaultwarden-failover-warning {
      position: fixed;
      inset: 0 0 auto 0;
      z-index: 2147483647;
      padding: 0.7rem 1rem;
      background: #8a4b08;
      color: white;
      font: 600 14px/1.4 sans-serif;
      text-align: center;
      box-shadow: 0 2px 6px rgb(0 0 0 / 35%);
    }
  '';

  failoverWebVault = pkgs.runCommand "vaultwarden-failover-web" { } ''
    mkdir -p "$out/share/vaultwarden"
    cp -R ${pkgs.vaultwarden.webvault}/share/vaultwarden/vault "$out/share/vaultwarden/vault"
    chmod -R u+w "$out/share/vaultwarden/vault"
    cp ${failoverWarningCss} "$out/share/vaultwarden/vault/failover-warning.css"
    substituteInPlace "$out/share/vaultwarden/vault/index.html" \
      --replace-fail '</head>' '<link rel="stylesheet" href="failover-warning.css"></head>' \
      --replace-fail '</body>' '<div id="vaultwarden-failover-warning" role="alert">EMERGENCY FAILOVER COPY: the home server is offline. Changes made here are not replicated back and will be lost on restore or failback.</div></body>'
  '';

  sshOptions = ''-o BatchMode=yes -o ConnectTimeout=10 -o ConnectionAttempts=1 -o UserKnownHostsFile=/home/${cfg.sshUser}/.ssh/known_hosts -i ${cfg.sshIdentityFile}'';

  markUploadFailed = destination: lib.optionalString destination.required ''upload_failed=1'';

  # This file is intentionally loaded after the encrypted environment file.
  # Host-specific routing and failover settings must not be overridden by an
  # older ROCKET_PORT or DATABASE_URL left in the shared secret.
  roleEnvironmentFile = pkgs.writeText "vaultwarden-${cfg.role}-environment" ''
    ROCKET_ADDRESS=0.0.0.0
    ROCKET_PORT=${toString cfg.port}
    DOMAIN=${cfg.domain}
    ${lib.optionalString (cfg.role == "standby") ''
      DATABASE_URL=sqlite:///var/lib/vaultwarden/db.sqlite3
      SIGNUPS_ALLOWED=false
      INVITATIONS_ALLOWED=false
    ''}
  '';

  uploadRolling = destination: ''
    if ${pkgs.openssh}/bin/ssh ${sshOptions} ${cfg.sshUser}@${destination.host} mkdir -p ${destination.directory} \
      && ${pkgs.openssh}/bin/scp ${sshOptions} "$STANDBY_BACKUP" ${cfg.sshUser}@${destination.host}:${destination.directory}/.vault-standby.tar.gz.uploading \
      && ${pkgs.openssh}/bin/ssh ${sshOptions} ${cfg.sshUser}@${destination.host} mv ${destination.directory}/.vault-standby.tar.gz.uploading ${destination.directory}/vault-standby.tar.gz; then
      echo "Updated Vaultwarden standby snapshot on ${destination.host}"
    else
      echo "Failed to update Vaultwarden standby snapshot on ${destination.host}" >&2
      ${markUploadFailed destination}
    fi
  '';

  uploadHourly = destination: ''
    hourly_name="$(${pkgs.coreutils}/bin/basename "$hourly_archive")"
    hourly_remote_dir=${destination.directory}/hourly
    if ${pkgs.openssh}/bin/ssh ${sshOptions} ${cfg.sshUser}@${destination.host} mkdir -p "$hourly_remote_dir" \
      && ${pkgs.openssh}/bin/scp ${sshOptions} "$hourly_archive" ${cfg.sshUser}@${destination.host}:"$hourly_remote_dir/.vault-hourly.tar.gz.uploading" \
      && ${pkgs.openssh}/bin/ssh ${sshOptions} ${cfg.sshUser}@${destination.host} mv "$hourly_remote_dir/.vault-hourly.tar.gz.uploading" "$hourly_remote_dir/$hourly_name" \
      && ${pkgs.openssh}/bin/ssh ${sshOptions} ${cfg.sshUser}@${destination.host} "find '$hourly_remote_dir' -maxdepth 1 -type f -name '*-vault-hourly.tar.gz' -mmin +${toString (cfg.hourlyRetentionHours * 60)} -delete"; then
      echo "Uploaded hourly Vaultwarden archive to ${destination.host}"
    else
      echo "Failed to update hourly Vaultwarden archives on ${destination.host}" >&2
      ${markUploadFailed destination}
    fi
  '';

  uploadArchive = destination: ''
    if ${pkgs.openssh}/bin/scp ${sshOptions} "$archive" ${cfg.sshUser}@${destination.host}:${destination.directory}/; then
      echo "Uploaded daily Vaultwarden archive to ${destination.host}"
    else
      echo "Failed to upload daily Vaultwarden archive to ${destination.host}" >&2
      ${markUploadFailed destination}
    fi
  '';
in
{
  options.services.vaultwardenReplication = {
    enable = lib.mkEnableOption "replicated Vaultwarden with restored failover standbys";

    role = lib.mkOption {
      type = lib.types.enum [ "master" "standby" ];
      description = "Whether this node is the writable master or a read-only standby.";
    };

    secretFile = lib.mkOption {
      type = lib.types.path;
      description = "Agenix file containing Vaultwarden secrets such as SMTP credentials.";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "https://vault.digdug.dev";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = if cfg.role == "master" then 8000 else 8222;
    };

    archiveDir = lib.mkOption {
      type = lib.types.str;
      default = if cfg.role == "master" then "/etc/vault/backups" else "/var/backup/vaultwarden";
      description = "Local directory for rolling, hourly, and daily archives.";
    };

    hourlyRetentionHours = lib.mkOption {
      type = lib.types.ints.positive;
      default = 48;
      description = "Number of hours to retain timestamped hourly snapshots.";
    };

    destinations = lib.mkOption {
      default = [ ];
      description = "Replication targets that receive backups; targets do not have to run a Vaultwarden standby.";
      type = lib.types.listOf (lib.types.submodule {
        options = {
          host = lib.mkOption { type = lib.types.str; };
          directory = lib.mkOption { type = lib.types.str; };
          required = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether an upload failure should fail the backup unit.";
          };
        };
      });
    };

    sshUser = lib.mkOption {
      type = lib.types.str;
      default = common.username;
    };

    sshIdentityFile = lib.mkOption {
      type = lib.types.str;
      default = "/home/${cfg.sshUser}/.ssh/id_ed25519";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf (lib.types.oneOf [ lib.types.bool lib.types.int lib.types.str ]);
      default = { };
      description = "Additional Vaultwarden environment settings.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg.role == "master" || cfg.destinations == [ ];
          message = "Vaultwarden standby nodes cannot have replication destinations.";
        }
      ];

      age = {
        identityPaths = [ "/home/${common.username}/.ssh/id_ed25519" ];
        secrets.vaultwarden.file = cfg.secretFile;
      };

      services.vaultwarden = {
        enable = true;
        environmentFile = [ config.age.secrets.vaultwarden.path roleEnvironmentFile ];
        config = {
          ROCKET_ADDRESS = "0.0.0.0";
          ROCKET_PORT = cfg.port;
          DOMAIN = cfg.domain;
          SIGNUPS_ALLOWED = false;
          ENABLE_WEBSOCKET = true;
        } // cfg.settings;
      };
    }

    (lib.mkIf (cfg.role == "master") {
      systemd.tmpfiles.rules = [
        "d ${cfg.archiveDir} 0750 root root -"
      ];

      systemd.services.backup-vault = {
        description = "Create and ship the rolling Vaultwarden standby snapshot";
        path = [ pkgs.coreutils pkgs.gnutar pkgs.sqlite pkgs.gzip ];
        script = ''
          set -euo pipefail

          DATA_FOLDER=/var/lib/vaultwarden
          BACKUP_FOLDER=${cfg.archiveDir}/staging
          STANDBY_BACKUP=${cfg.archiveDir}/vault-standby.tar.gz
          hourly_dir=${cfg.archiveDir}/hourly
          hourly_archive="$hourly_dir/$(date -u +%Y-%m-%d-%H-%M)-vault-hourly.tar.gz"
          rm -rf "$BACKUP_FOLDER"
          mkdir -p "$BACKUP_FOLDER" "$hourly_dir"
          trap 'rm -rf "$BACKUP_FOLDER" "$STANDBY_BACKUP.tmp" "$hourly_archive.tmp"' EXIT

          if [[ ! -f "$DATA_FOLDER/db.sqlite3" ]]; then
            echo "Could not find SQLite database file '$DATA_FOLDER/db.sqlite3'" >&2
            exit 1
          fi

          ${pkgs.sqlite}/bin/sqlite3 "$DATA_FOLDER/db.sqlite3" ".backup '$BACKUP_FOLDER/db.sqlite3'"
          for payload in attachments sends; do
            if [[ -d "$DATA_FOLDER/$payload" ]]; then
              cp -a "$DATA_FOLDER/$payload" "$BACKUP_FOLDER/$payload"
            fi
          done
          for key in "$DATA_FOLDER"/rsa_key*; do
            if [[ -f "$key" ]]; then
              cp -a "$key" "$BACKUP_FOLDER/"
            fi
          done

          ${pkgs.gnutar}/bin/tar -C "$BACKUP_FOLDER" -czf "$STANDBY_BACKUP.tmp" .
          mv "$STANDBY_BACKUP.tmp" "$STANDBY_BACKUP"

          cp --reflink=auto "$STANDBY_BACKUP" "$hourly_archive.tmp"
          mv "$hourly_archive.tmp" "$hourly_archive"
          ${pkgs.findutils}/bin/find "$hourly_dir" -maxdepth 1 -type f -name '*-vault-hourly.tar.gz' -mmin +${toString (cfg.hourlyRetentionHours * 60)} -delete

          upload_failed=0
          ${lib.concatMapStringsSep "\n" uploadRolling cfg.destinations}
          ${lib.concatMapStringsSep "\n" uploadHourly cfg.destinations}
          exit "$upload_failed"
        '';
        serviceConfig = {
          User = "root";
          Type = "oneshot";
          UMask = "0077";
        };
        startAt = "*-*-* *:00:00";
      };

      systemd.services.archive-vault = {
        description = "Keep and ship the daily Vaultwarden archive";
        wants = [ "backup-vault.service" ];
        after = [ "backup-vault.service" ];
        path = [ pkgs.coreutils ];
        script = ''
          set -euo pipefail

          prefix="$(date -u +%Y-%m-%d-%H-%M)"
          source=${cfg.archiveDir}/vault-standby.tar.gz
          archive="${cfg.archiveDir}/$prefix-vault-backup.tar.gz"

          if [[ ! -f "$source" ]]; then
            echo "Could not find rolling Vaultwarden snapshot '$source'" >&2
            exit 1
          fi

          snapshot_age=$(($(date -u +%s) - $(stat -c %Y "$source")))
          if (( snapshot_age > 7200 )); then
            echo "Rolling Vaultwarden snapshot is $snapshot_age seconds old; refusing to create a stale daily archive" >&2
            exit 1
          fi

          cp --reflink=auto "$source" "$archive"

          upload_failed=0
          ${lib.concatMapStringsSep "\n" uploadArchive cfg.destinations}
          exit "$upload_failed"
        '';
        serviceConfig = {
          User = "root";
          Type = "oneshot";
          UMask = "0077";
        };
        startAt = "*-*-* 02:15:00";
      };
    })

    (lib.mkIf (cfg.role == "standby") {
      services.vaultwarden = {
        webVaultPackage = failoverWebVault;
        config = {
          INVITATIONS_ALLOWED = false;
        };
      };

      systemd.tmpfiles.rules = [
        "d ${cfg.archiveDir} 0750 ${cfg.sshUser} users -"
      ];

      systemd.services = {
        vaultwarden = {
          wantedBy = lib.mkForce [ ];
        };

        restore-vaultwarden-standby = {
          description = "Restore the latest Vaultwarden backup into the read-only standby";
          unitConfig.RequiresMountsFor = [ cfg.archiveDir ];
          path = [ pkgs.coreutils pkgs.findutils pkgs.gnutar pkgs.gzip pkgs.sqlite pkgs.systemd pkgs.curl ];
          script = ''
            set -euo pipefail

            backup_dir=${cfg.archiveDir}
            data_dir=/var/lib/vaultwarden
            marker="$data_dir/.restored-backup"
            latest="$backup_dir/vault-standby.tar.gz"

            if [[ ! -f "$latest" ]]; then
              latest_name="$(${pkgs.findutils}/bin/find "$backup_dir" -maxdepth 1 -type f -name '*-vault-backup.tar.gz' -printf '%f\n' | ${pkgs.coreutils}/bin/sort | ${pkgs.coreutils}/bin/tail -n 1)"
              if [[ -z "$latest_name" ]]; then
                echo "No Vaultwarden backup found in $backup_dir" >&2
                exit 1
              fi
              latest="$backup_dir/$latest_name"
            fi

            latest_hash="$(${pkgs.coreutils}/bin/sha256sum "$latest" | ${pkgs.coreutils}/bin/cut -d ' ' -f 1)"
            marker_value="writable-v1:$latest_hash"
            ${pkgs.coreutils}/bin/install -d -o vaultwarden -g vaultwarden -m 0700 "$data_dir/tmp"
            if [[ -f "$marker" ]] && [[ "$(<"$marker")" == "$marker_value" ]]; then
              systemctl reset-failed vaultwarden.service
              systemctl start vaultwarden.service
              exit 0
            fi

            work_dir="$(${pkgs.coreutils}/bin/mktemp -d)"
            trap '${pkgs.coreutils}/bin/rm -rf "$work_dir"' EXIT
            ${pkgs.gnutar}/bin/tar -xzf "$latest" -C "$work_dir"

            staged_db="$(${pkgs.findutils}/bin/find "$work_dir" -type f -name db.sqlite3 -print -quit)"
            if [[ -z "$staged_db" ]]; then
              echo "Backup $latest does not contain db.sqlite3" >&2
              exit 1
            fi

            if [[ "$(${pkgs.sqlite}/bin/sqlite3 "$staged_db" 'PRAGMA integrity_check;')" != "ok" ]]; then
              echo "SQLite integrity check failed for $latest" >&2
              exit 1
            fi

            staged_dir="$(${pkgs.coreutils}/bin/dirname "$staged_db")"
            systemctl stop vaultwarden.service
            ${pkgs.coreutils}/bin/install -d -o vaultwarden -g vaultwarden -m 0700 "$data_dir"
            ${pkgs.coreutils}/bin/rm -f "$data_dir/db.sqlite3-wal" "$data_dir/db.sqlite3-shm"
            ${pkgs.coreutils}/bin/install -o vaultwarden -g vaultwarden -m 0600 "$staged_db" "$data_dir/db.sqlite3"

            for key in "$staged_dir"/rsa_key*; do
              if [[ -f "$key" ]]; then
                ${pkgs.coreutils}/bin/install -o vaultwarden -g vaultwarden -m 0600 "$key" "$data_dir/$(${pkgs.coreutils}/bin/basename "$key")"
              fi
            done

            for payload in attachments sends; do
              ${pkgs.coreutils}/bin/rm -rf "$data_dir/$payload"
              if [[ -d "$staged_dir/$payload" ]]; then
                ${pkgs.coreutils}/bin/cp -a "$staged_dir/$payload" "$data_dir/$payload"
                ${pkgs.coreutils}/bin/chown -R vaultwarden:vaultwarden "$data_dir/$payload"
                ${pkgs.coreutils}/bin/chmod -R u=rwX,go= "$data_dir/$payload"
              fi
            done

            systemctl reset-failed vaultwarden.service
            systemctl start vaultwarden.service
            for attempt in {1..10}; do
              if ${pkgs.curl}/bin/curl --fail --silent http://127.0.0.1:${toString cfg.port}/alive >/dev/null; then
                printf '%s\n' "$marker_value" > "$marker"
                exit 0
              fi
              sleep 1
            done

            echo "Restored Vaultwarden standby failed its local health check" >&2
            exit 1
          '';
          serviceConfig = {
            Type = "oneshot";
            User = "root";
          };
        };
      };

      systemd.timers.restore-vaultwarden-standby = {
        description = "Refresh the Vaultwarden standby from incoming backups";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "1min";
          OnUnitActiveSec = "5min";
          Persistent = true;
        };
      };
    })
  ]);
}
